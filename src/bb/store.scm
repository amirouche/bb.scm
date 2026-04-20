(library (bb store)

  (export store-find-root
          store-combiner!
          store-mapping!
          store-record-lineage!
          store-record-wip-lineage!
          store-list-wip-files
          store-has-committed-lineage?
          store-load-combiner
          store-load-mapping
          store-load-first-mapping
          store-load-mapping-by-language
          store-find-all-map-files
          store-list-all-stored-hashes
          store-build-name-index
          store-add-worklog-entry!
          store-list-worklog-entries
          store-mark-reviewed!
          store-is-reviewed?
          store-load-review
          store-config-languages
          store-load-preferred-mapping
          store-config-remotes
          store-set-config-remotes!
          store-copy-combiner!
          store-copy-directory!
          store-delete-directory!
          store-combiner-directory
          store-combiner-tree-path
          store-mapping-path
          store-config-author
          store-path-join
          store-ensure-directory
          store-string-suffix?
          ~check-store-path-join
          ~check-store-hash-split-path
          ~check-store-wip-lineage
          ~check-store-worklog
          ~check-store-review
          store-make-short-hash
          store-combiner-latest-timestamp
          store-load-checks-for-combiner
          store-load-checks
          store-record-wip-retract-checks!
          store-record-retract-checks!
          ~check-store-short-hash
          ~check-store-validate
          ~check-store-load-checks
          store-remote-entry-url
          store-remote-entry-path
          store-delete-mapping!
          store-list-mappings
          store-remote-entry-read-only?
          store-current-iso-timestamp
          store-timestamp-request!
          store-timestamp-upgrade!
          store-timestamp-combiner!
          ~check-store-timestamp)

  (import (chezscheme)
          (bb values)
          (bb hash)
          (bb serialization))

  ;; ================================================================
  ;; Path utilities
  ;; ================================================================

  (define store-path-join
    (lambda parts
      (let loop ((remaining parts)
                 (accumulated ""))
        (if (null? remaining)
            accumulated
            (let ((part (car remaining)))
              (loop (cdr remaining)
                    (if (string=? accumulated "")
                        part
                        (string-append accumulated "/" part))))))))

  (define store-ensure-directory
    (lambda (path)
      ;; Create directory and parents if they don't exist
      (let loop ((components (string-split path #\/))
                 (current ""))
        (unless (null? components)
          (let ((next (if (string=? current "")
                          (if (and (> (string-length path) 0)
                                   (char=? (string-ref path 0) #\/))
                              (string-append "/" (car components))
                              (car components))
                          (string-append current "/" (car components)))))
            (when (and (> (string-length next) 0)
                       (not (file-exists? next)))
              (mkdir next))
            (loop (cdr components) next))))))

  (define string-split
    (lambda (string delimiter)
      (let loop ((index 0)
                 (start 0)
                 (parts '()))
        (cond
         ((= index (string-length string))
          (reverse (cons (substring string start index) parts)))
         ((char=? (string-ref string index) delimiter)
          (loop (+ index 1) (+ index 1)
                (cons (substring string start index) parts)))
         (else
          (loop (+ index 1) start parts))))))

  ;; ================================================================
  ;; Store root discovery
  ;; ================================================================

  (define store-find-root
    (lambda (start-directory)
      (let loop ((directory start-directory))
        (let ((config-path (store-path-join directory "config.scm")))
          (if (file-exists? config-path)
              directory
              (let ((parent (store-path-join directory "..")))
                (if (string=? (store-real-path directory) (store-real-path parent))
                    (error 'store-find-root "no mobius store found")
                    (loop parent))))))))

  (define store-real-path
    (lambda (path)
      ;; Simple realpath: resolve . and ..
      ;; For full implementation, would use POSIX realpath
      path))

  ;; ================================================================
  ;; Path derivation
  ;; ================================================================

  (define store-combiner-directory
    (lambda (root function-hash)
      (store-path-join root "combiners" function-hash)))

  (define store-combiner-tree-path
    (lambda (root function-hash)
      (store-path-join (store-combiner-directory root function-hash) "tree.scm")))

  (define store-mapping-path
    (lambda (root function-hash mapping-hash)
      (store-path-join (store-combiner-directory root function-hash)
                 "mappings" mapping-hash "map.scm")))

  ;; ================================================================
  ;; Store operations
  ;; ================================================================

  ;; Write tree.scm for a combiner. Stores the bare de Bruijn tree.
  ;; Truly immutable — if tree.scm exists, skip.
  (define store-combiner!
    (lambda (root function-hash body)
      (let* ((tree-path (store-combiner-tree-path root function-hash))
             (directory (store-combiner-directory root function-hash))
             (content (scheme-write-value body)))
        (unless (file-exists? tree-path)
          (store-ensure-directory directory)
          (call-with-output-file tree-path
            (lambda (port) (display content port))))))
)

  ;; Write map.scm for a mapping. Idempotent.
  (define store-mapping!
    (lambda (root function-hash language mapping doc)
      (let* ((content (sorted-alist->string
                       (list (cons 'doc doc)
                             (cons 'function function-hash)
                             (cons 'language language)
                             (cons 'mapping mapping))))
             (mapping-hash (sha256-string content))
             (map-path (store-mapping-path root function-hash mapping-hash))
             (map-directory (store-path-join (store-combiner-directory root function-hash)
                                       "mappings" mapping-hash)))
        (unless (file-exists? map-path)
          (store-ensure-directory map-directory)
          (call-with-output-file map-path
            (lambda (port) (display content port))))
        mapping-hash)))

  ;; Delete a specific mapping by its hash.
  (define store-delete-mapping!
    (lambda (root function-hash mapping-hash)
      (let ((map-directory (store-path-join (store-combiner-directory root function-hash)
                                       "mappings" mapping-hash)))
        (when (file-exists? map-directory)
          (store-delete-directory! map-directory)))))

  ;; List all mappings for a combiner.
  ;; Returns list of (mapping-hash . map-data) pairs.
  (define store-list-mappings
    (lambda (root function-hash)
      (let ((mappings-dir (store-path-join (store-combiner-directory root function-hash)
                                       "mappings")))
        (if (not (file-exists? mappings-dir))
            '()
            (let loop ((entries (directory-list mappings-dir)) (acc '()))
              (if (null? entries)
                  (reverse acc)
                  (let* ((entry (car entries))
                         (map-file (store-path-join mappings-dir entry "map.scm")))
                    (if (file-exists? map-file)
                        (let ((map-data (call-with-input-file map-file read)))
                          (loop (cdr entries) (cons (cons entry map-data) acc)))
                        (loop (cdr entries) acc)))))))))

  ;; Write a committed lineage record. Idempotent.
  (define store-record-lineage!
    (lambda (root function-hash author relation . optional)
      (let* ((derived-from (if (>= (length optional) 1) (car optional) #f))
             (note (if (>= (length optional) 2) (cadr optional) #f))
             (replaces (if (>= (length optional) 3) (caddr optional) #f))
             (checks (if (>= (length optional) 4) (cadddr optional) #f))
             (timestamp (store-current-iso-timestamp))
             (alist (filter cdr
                      (list (cons 'author author)
                            (cons 'checks (if (and checks (pair? checks)) checks #f))
                            (cons 'committed timestamp)
                            (cons 'derived-from derived-from)
                            (cons 'note note)
                            (cons 'relation relation)
                            (cons 'replaces replaces))))
             (content (sorted-alist->string alist))
             (content-hash (sha256-string content))
             (lineage-directoryectory (store-path-join (store-combiner-directory root function-hash)
                                           "lineage"))
             (lineage-path (store-path-join lineage-directoryectory
                                       (string-append content-hash ".committed.scm"))))
        (unless (file-exists? lineage-path)
          (store-ensure-directory lineage-directoryectory)
          (call-with-output-file lineage-path
            (lambda (port) (display content port))))
        content-hash)))


  ;; Write a committed lineage record that retracts specific check hashes.
  (define store-record-retract-checks!
    (lambda (root function-hash author check-hashes)
      (let* ((timestamp (store-current-iso-timestamp))
             (alist (list (cons 'author author)
                          (cons 'committed timestamp)
                          (cons 'relation "retract-checks")
                          (cons 'retract-checks check-hashes)))
             (content (sorted-alist->string alist))
             (content-hash (sha256-string content))
             (lineage-dir (store-path-join (store-combiner-directory root function-hash) "lineage"))
             (lineage-path (store-path-join lineage-dir (string-append content-hash ".committed.scm"))))
        (unless (file-exists? lineage-path)
          (store-ensure-directory lineage-dir)
          (call-with-output-file lineage-path
            (lambda (port) (display content port))))
        content-hash)))

  ;; ================================================================
  ;; Load operations
  ;; ================================================================

  ;; Load tree.scm — returns the bare de Bruijn tree directly.
  ;; Handles both new format (bare tree) and legacy format (alist with 'body).
  (define store-load-combiner
    (lambda (root function-hash)
      (let ((tree-path (store-combiner-tree-path root function-hash)))
        (if (file-exists? tree-path)
            (let ((data (call-with-input-file tree-path read)))
              ;; Legacy format: ((body . ...) (checks . ...))
              (if (and (pair? data) (pair? (car data)) (eq? 'body (caar data)))
                  (cdr (assq 'body data))
                  ;; New format: bare tree
                  data))
            (error 'store-load-combiner "combiner not found" function-hash)))))

  (define store-load-mapping
    (lambda (root function-hash mapping-hash)
      (let ((map-path (store-mapping-path root function-hash mapping-hash)))
        (if (file-exists? map-path)
            (call-with-input-file map-path read)
            (error 'store-load-mapping "mapping not found" function-hash mapping-hash)))))

  ;; Find and load the first mapping for a combiner.
  ;; Walks the mappings/ directory tree to find the first map.scm.
  (define store-load-first-mapping
    (lambda (root function-hash)
      (let* ((mappings-directoryectory (store-path-join (store-combiner-directory root function-hash)
                                            "mappings"))
             (map-file (store-find-map-file mappings-directoryectory)))
        (if map-file
            (call-with-input-file map-file read)
            (error 'store-load-first-mapping "no mapping found" function-hash)))))

  ;; Recursively find the first map.scm in a directory tree
  (define store-find-map-file
    (lambda (directory)
      (if (not (file-exists? directory))
          #f
          (let loop ((entries (directory-list directory)))
            (if (null? entries)
                #f
                (let ((path (store-path-join directory (car entries))))
                  (cond
                   ((string=? (car entries) "map.scm") path)
                   ((file-directory? path)
                    (or (store-find-map-file path)
                        (loop (cdr entries))))
                   (else (loop (cdr entries))))))))))

  ;; Recursively find all map.scm files in a directory tree
  (define store-find-all-map-files
    (lambda (directory)
      (if (not (file-exists? directory))
          '()
          (let loop ((entries (directory-list directory)) (acc '()))
            (if (null? entries)
                acc
                (let ((path (store-path-join directory (car entries))))
                  (cond
                   ((string=? (car entries) "map.scm")
                    (loop (cdr entries) (cons path acc)))
                   ((file-directory? path)
                    (loop (cdr entries) (append (store-find-all-map-files path) acc)))
                   (else (loop (cdr entries) acc)))))))))

  ;; Load the mapping for a combiner that matches the given language.
  ;; Scans all map.scm files and returns the first with (language . lang).
  (define store-load-mapping-by-language
    (lambda (root function-hash lang)
      (let* ((mappings-directoryectory (store-path-join (store-combiner-directory root function-hash)
                                            "mappings"))
             (map-files (store-find-all-map-files mappings-directoryectory)))
        ;; Among all mappings matching lang, return the most recently modified one.
        (let loop ((remaining map-files) (best-mtime #f) (best-data #f))
          (if (null? remaining)
              (if best-data
                  best-data
                  (error 'store-load-mapping-by-language
                         (string-append "no mapping for language '" lang
                                        "'. Use 'bb add <file> " lang
                                        "' to create one.")
                         function-hash))
              (let* ((path (car remaining))
                     (map-data (call-with-input-file path read))
                     (lang-entry (assq 'language map-data)))
                (if (and lang-entry (string=? (cdr lang-entry) lang))
                    (let ((mtime (file-modification-time path)))
                      (if (or (not best-mtime) (time>? mtime best-mtime))
                          (loop (cdr remaining) mtime map-data)
                          (loop (cdr remaining) best-mtime best-data)))
                    (loop (cdr remaining) best-mtime best-data))))))))

  ;; ================================================================
  ;; Config
  ;; ================================================================

  (define store-config-author
    (lambda (root)
      (let* ((config-path (store-path-join root "config.scm"))
             (config (call-with-input-file config-path read))
             (author-entry (assq 'author config)))
        (if author-entry
            (let* ((author-data (if (and (pair? (cdr author-entry))
                                         (pair? (cadr author-entry)))
                                    (cadr author-entry)
                                    (cdr author-entry)))
                   (name-entry (assq 'name author-data)))
              (if name-entry
                  (cdr name-entry)
                  (error 'store-config-author "no author.name in config")))
            (error 'store-config-author "no author in config")))))

  (define store-config-languages
    (lambda (root)
      (let* ((config-path (store-path-join root "config.scm"))
             (config (call-with-input-file config-path read))
             (author-entry (assq 'author config)))
        (if author-entry
            (let* ((author-data (if (and (pair? (cdr author-entry))
                                         (pair? (cadr author-entry)))
                                    (cadr author-entry)
                                    (cdr author-entry)))
                   (lang-entry (assq 'languages author-data)))
              (if lang-entry
                  ;; (languages "en" "fr" "kab") -> cdr is ("en" "fr" "kab")
                  (let ((raw (cdr lang-entry)))
                    (if (and (pair? raw) (for-all string? raw))
                        raw
                        '("en")))

                  '("en")))
            '("en")))))

  ;; Load the mapping for a combiner that best matches the user's language preferences.
  ;; Tries each preferred language in order, falls back to store-load-first-mapping.
  (define store-load-preferred-mapping
    (lambda (root function-hash)
      (let ((langs (guard (exn (#t '("en")))
                     (store-config-languages root))))
        (let loop ((remaining langs))
          (if (null? remaining)
              (store-load-first-mapping root function-hash)
              (guard (exn (#t (loop (cdr remaining))))
                (store-load-mapping-by-language root function-hash (car remaining))))))))

  ;; ================================================================
  ;; Timestamp
  ;; ================================================================

  (define store-current-iso-timestamp
    (lambda ()
      (let ((time (current-time 'time-utc)))
        ;; Format: "2026-02-19T14:30:45Z"
        ;; Use Chez Scheme's date facilities
        (let ((date (time-utc->date time 0)))
          (format #f "~4d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0dZ"
                  (date-year date) (date-month date) (date-day date)
                  (date-hour date) (date-minute date) (date-second date))))))

  ;; ================================================================
  ;; String utilities
  ;; ================================================================

  (define store-string-suffix?
    (lambda (suffix string)
      (let ((suffix-length (string-length suffix))
            (total-length (string-length string)))
        (and (>= total-length suffix-length)
             (string=? suffix (substring string (- total-length suffix-length) total-length))))))

  ;; ================================================================
  ;; WIP Lineage
  ;; ================================================================

  (define store-record-wip-lineage!
    (lambda (root function-hash author relation . optional)
      (let* ((derived-from (if (>= (length optional) 1) (car optional) #f))
             (note (if (>= (length optional) 2) (cadr optional) #f))
             (checks (if (>= (length optional) 3) (caddr optional) #f))
             (timestamp (store-current-iso-timestamp))
             (alist (filter cdr
                      (list (cons 'author author)
                            (cons 'checks (if (and checks (pair? checks)) checks #f))
                            (cons 'created timestamp)
                            (cons 'derived-from derived-from)
                            (cons 'note note)
                            (cons 'relation relation))))
             (content (sorted-alist->string alist))
             (content-hash (sha256-string content))
             (lineage-directoryectory (store-path-join (store-combiner-directory root function-hash)
                                      "lineage"))
             (lineage-path (store-path-join lineage-directoryectory
                                       (string-append content-hash ".wip.scm"))))
        (unless (file-exists? lineage-path)
          (store-ensure-directory lineage-directoryectory)
          (call-with-output-file lineage-path
            (lambda (port) (display content port))))
        content-hash)))

  (define store-list-wip-files
    (lambda (root function-hash)
      (let ((lineage-directory (store-path-join (store-combiner-directory root function-hash)
                                     "lineage")))
        (if (file-exists? lineage-directory)
            (filter (lambda (f) (store-string-suffix? ".wip.scm" f))
                    (directory-list lineage-directory))
            '()))))

  (define store-list-committed-files
    (lambda (root function-hash)
      (let ((lineage-directory (store-path-join (store-combiner-directory root function-hash)
                                     "lineage")))
        (if (file-exists? lineage-directory)
            (filter (lambda (f) (store-string-suffix? ".committed.scm" f))
                    (directory-list lineage-directory))
            '()))))

  ;; Load checks using per-check timestamp ordering: for each check hash, collect
  ;; all add and retract events across every lineage record, then keep only those
  ;; whose most recent event is an add. Events from retract-checks records beat
  ;; events from checks records when timestamps are equal (retract wins on tie).
  (define store-load-checks-for-combiner
    (lambda (root function-hash)
      (let* ((lineage-directory (store-path-join (store-combiner-directory root function-hash)
                                      "lineage"))
             (wip-files (store-list-wip-files root function-hash))
             (committed-files (store-list-committed-files root function-hash))
             (all-files (append
                         (map (lambda (f) (store-path-join lineage-directory f)) wip-files)
                         (map (lambda (f) (store-path-join lineage-directory f)) committed-files)))
             ;; events: alist of check-hash -> (timestamp . action) where action is 'add or 'retract
             ;; We keep the event with the latest timestamp per check hash.
             ;; On equal timestamps, 'retract beats 'add.
             (update-events
              (lambda (events check-hash ts action)
                (let ((existing (assoc check-hash events)))
                  (if existing
                      (let* ((prev-ts (cadr existing))
                             (prev-action (cddr existing))
                             (newer? (or (string>? ts prev-ts)
                                         (and (string=? ts prev-ts)
                                              (eq? action 'retract)))))
                        (if newer?
                            (cons (cons check-hash (cons ts action))
                                  (filter (lambda (e) (not (equal? (car e) check-hash))) events))
                            events))
                      (cons (cons check-hash (cons ts action)) events))))))
        (let loop ((remaining all-files) (events '()))
          (if (null? remaining)
              (map car (filter (lambda (e) (eq? (cddr e) 'add)) events))
              (guard (exn (#t (loop (cdr remaining) events)))
                (let* ((record (call-with-input-file (car remaining) read))
                       (ts (or (let ((c (assq 'committed record))) (and c (cdr c)))
                               (let ((c (assq 'created record))) (and c (cdr c)))
                               ""))
                       (adds (let ((e (assq 'checks record)))
                               (if (and e (list? (cdr e))) (cdr e) '())))
                       (retracts (let ((e (assq 'retract-checks record)))
                                   (if (and e (list? (cdr e))) (cdr e) '())))
                       (events1 (fold-left (lambda (ev h) (update-events ev h ts 'add))
                                           events adds))
                       (events2 (fold-left (lambda (ev h) (update-events ev h ts 'retract))
                                           events1 retracts)))
                  (loop (cdr remaining) events2))))))))

  ;; Write a lineage record that retracts specific check hashes. Append-only:
  ;; store-load-checks-for-combiner will subtract these from the union.
  (define store-record-wip-retract-checks!
    (lambda (root function-hash author check-hashes)
      (let* ((timestamp (store-current-iso-timestamp))
             (alist (list (cons 'author author)
                          (cons 'created timestamp)
                          (cons 'relation "retract-checks")
                          (cons 'retract-checks check-hashes)))
             (content (sorted-alist->string alist))
             (content-hash (sha256-string content))
             (lineage-dir (store-path-join (store-combiner-directory root function-hash) "lineage"))
             (lineage-path (store-path-join lineage-dir (string-append content-hash ".wip.scm"))))
        (unless (file-exists? lineage-path)
          (store-ensure-directory lineage-dir)
          (call-with-output-file lineage-path
            (lambda (port) (display content port))))
        content-hash)))

  ;; Also support loading checks from legacy tree.scm format (alist with checks field).
  ;; This is used as a fallback when no lineage has checks.
  (define store-load-checks-for-combiner-legacy
    (lambda (root function-hash)
      (let ((tree-path (store-combiner-tree-path root function-hash)))
        (if (file-exists? tree-path)
            (let ((data (call-with-input-file tree-path read)))
              (if (and (pair? data) (pair? (car data)) (eq? 'body (caar data)))
                  (let ((checks-entry (assq 'checks data)))
                    (if checks-entry
                        (let ((raw (cdr checks-entry)))
                          (if (and (pair? raw)
                                   (eq? 'mobius-primitive-constant-ref (car raw)))
                              '()
                              (if (list? raw) raw '())))
                        '()))
                  '()))
            '()))))

  ;; Load checks: try lineage first, fall back to legacy tree.scm format.
  (define store-load-checks
    (lambda (root function-hash)
      (let ((checks (store-load-checks-for-combiner root function-hash)))
        (if (null? checks)
            (store-load-checks-for-combiner-legacy root function-hash)
            checks))))

  (define store-has-committed-lineage?
    (lambda (root function-hash)
      (let ((lineage-directory (store-path-join (store-combiner-directory root function-hash)
                                     "lineage")))
        (and (file-exists? lineage-directory)
             (pair? (filter (lambda (f) (store-string-suffix? ".committed.scm" f))
                            (directory-list lineage-directory)))))))

  ;; ================================================================
  ;; Store Enumeration
  ;; ================================================================

  (define store-list-all-stored-hashes
    (lambda (root)
      (let ((combiners-directory (store-path-join root "combiners")))
        (if (not (file-exists? combiners-directory))
            '()
            (filter (lambda (entry)
                      (file-directory? (store-path-join combiners-directory entry)))
                    (directory-list combiners-directory))))))

  ;; ================================================================
  ;; Short Hash — minimum unique prefix (>= 6 chars)
  ;; ================================================================

  ;; Given a list of all hashes in the store, return a function
  ;; hash→short-prefix. Each prefix is the shortest substring (min 6
  ;; chars) that uniquely identifies the hash among all others.
  (define store-make-short-hash
    (lambda (all-hashes)
      (let ((table (make-hashtable string-hash string=?)))
        (for-each
         (lambda (h)
           (let loop ((prefix-length 6))
             (if (>= prefix-length (string-length h))
                 (hashtable-set! table h h)
                 (let ((prefix (substring h 0 prefix-length)))
                   (if (= 1 (length (filter
                                     (lambda (other)
                                       (and (>= (string-length other) prefix-length)
                                            (string=? prefix
                                                      (substring other 0 prefix-length))))
                                     all-hashes)))
                       (hashtable-set! table h prefix)
                       (loop (+ prefix-length 1)))))))
         all-hashes)
        (lambda (h)
          (hashtable-ref table h
                         (substring h 0 (min 12 (string-length h))))))))

  ;; ================================================================
  ;; Name Index — scan store to build name→hash mapping
  ;; ================================================================

  ;; Get the latest lineage timestamp for a combiner.
  ;; Reads all lineage files and returns the most recent ISO timestamp,
  ;; or #f if no lineage exists.
  (define store-combiner-latest-timestamp
    (lambda (root function-hash)
      (let ((lineage-directory (store-path-join (store-combiner-directory root function-hash)
                                     "lineage")))
        (if (not (file-exists? lineage-directory))
            #f
            (let ((files (filter (lambda (f) (store-string-suffix? ".scm" f))
                                 (directory-list lineage-directory))))
              (let loop ((remaining files) (latest #f))
                (if (null? remaining)
                    latest
                    (let* ((record (call-with-input-file
                                    (store-path-join lineage-directory (car remaining))
                                    read))
                           (ts (or (let ((c (assq 'committed record)))
                                     (and c (cdr c)))
                                   (let ((c (assq 'created record)))
                                     (and c (cdr c))))))
                      (loop (cdr remaining)
                            (if (and ts (or (not latest) (string>? ts latest)))
                                ts
                                latest))))))))))

  ;; Scan the store and build a name→hash index.
  ;; For each combiner, extracts the name from its mapping (index 0).
  ;; When multiple combiners share a name, keeps the one with the
  ;; latest lineage timestamp.
  ;; Returns a sorted alist: ((name . hash) ...)
  ;; When multiple combiners share the same name, disambiguates as name@shortHash.
  (define store-build-name-index
    (lambda (root)
      (let* ((all-hashes (store-list-all-stored-hashes root))
             (short-hash (store-make-short-hash all-hashes))
             ;; name-table: name -> list of hashes
             (name-table (make-hashtable string-hash string=?)))
        ;; For each combiner, collect all names
        (for-each
         (lambda (function-hash)
           (guard (exn (#t (void)))  ;; skip combiners with broken mappings
             (let* ((map-data (store-load-preferred-mapping root function-hash))
                    (mapping (cdr (assq 'mapping map-data)))
                    (name-entry (assv 0 mapping)))
               (when name-entry
                 (let* ((name (cdr name-entry))
                        (existing (hashtable-ref name-table name '())))
                   (unless (member function-hash existing)
                     (hashtable-set! name-table name
                                     (cons function-hash existing))))))))
         all-hashes)
        ;; Convert to sorted alist, disambiguating collisions
        (let-values (((keys values) (hashtable-entries name-table)))
          (sort (lambda (a b) (string<? (car a) (car b)))
                (let loop ((i 0) (acc '()))
                  (if (= i (vector-length keys))
                      acc
                      (let* ((name (vector-ref keys i))
                             (hashes (vector-ref values i)))
                        (if (= (length hashes) 1)
                            ;; Unique name — no disambiguation needed
                            (loop (+ i 1)
                                  (cons (cons name (car hashes)) acc))
                            ;; Collision — disambiguate with name@shortHash
                            (loop (+ i 1)
                                  (append
                                   (map (lambda (h)
                                          (cons (string-append name "@" (short-hash h))
                                                h))
                                        hashes)
                                   acc)))))))))))

  ;; ================================================================
  ;; Worklog
  ;; ================================================================

  (define store-add-worklog-entry!
    (lambda (root function-hash message)
      (let* ((timestamp (store-current-iso-timestamp))
             (alist (list (cons 'combiner function-hash)
                          (cons 'message message)
                          (cons 'timestamp timestamp)))
             (content (sorted-alist->string alist))
             (entry-hash (sha256-string content))
             (worklog-directory (store-path-join root "worklog"))
             (entry-path (store-path-join worklog-directory
                                     (string-append entry-hash ".scm"))))
        (store-ensure-directory worklog-directory)
        (unless (file-exists? entry-path)
          (call-with-output-file entry-path
            (lambda (port) (display content port))))
        entry-hash)))

  (define store-list-worklog-entries
    (lambda (root . optional-hash)
      (let* ((worklog-directory (store-path-join root "worklog"))
             (filter-hash (if (null? optional-hash) #f (car optional-hash))))
        (if (not (file-exists? worklog-directory))
            '()
            (let* ((files (filter (lambda (f) (store-string-suffix? ".scm" f))
                                  (directory-list worklog-directory)))
                   (entries (map (lambda (f)
                                  (call-with-input-file
                                    (store-path-join worklog-directory f) read))
                                files))
                   (filtered (if filter-hash
                                (filter (lambda (e)
                                          (let ((c (assq 'combiner e)))
                                            (and c (string=? (cdr c) filter-hash))))
                                        entries)
                                entries)))
              (sort (lambda (a b)
                      (string<? (cdr (assq 'timestamp a))
                                (cdr (assq 'timestamp b))))
                    filtered))))))

  ;; ================================================================
  ;; Review Tracking
  ;; ================================================================

  (define store-mark-reviewed!
    (lambda (root function-hash reviewer)
      (let* ((timestamp (store-current-iso-timestamp))
             (alist (list (cons 'combiner function-hash)
                          (cons 'reviewed-at timestamp)
                          (cons 'reviewer reviewer)))
             (content (sorted-alist->string alist))
             (reviewed-directory (store-path-join root "reviewed"))
             (review-directory (store-path-join reviewed-directory function-hash))
             (review-path (store-path-join review-directory "review.scm")))
        (store-ensure-directory review-directory)
        (call-with-output-file review-path
          (lambda (port) (display content port))
          'replace))))

  (define store-is-reviewed?
    (lambda (root function-hash)
      (let* ((review-path (store-path-join root "reviewed"
                                      function-hash "review.scm")))
        (file-exists? review-path))))

  (define store-load-review
    (lambda (root function-hash)
      (let* ((review-path (store-path-join root "reviewed"
                                      function-hash "review.scm")))
        (if (file-exists? review-path)
            (call-with-input-file review-path read)
            #f))))

  ;; ================================================================
  ;; Remote Configuration
  ;; ================================================================

  (define store-config-remotes
    (lambda (root)
      (let* ((config-path (store-path-join root "config.scm"))
             (config (call-with-input-file config-path read))
             (remotes-entry (assq 'remotes config)))
        (if remotes-entry (cdr remotes-entry) '()))))

  (define store-set-config-remotes!
    (lambda (root remotes)
      (let* ((config-path (store-path-join root "config.scm"))
             (config (call-with-input-file config-path read))
             (new-config (map (lambda (entry)
                                (if (eq? 'remotes (car entry))
                                    (cons 'remotes remotes)
                                    entry))
                              config)))
        (call-with-output-file config-path
          (lambda (port) (pretty-print new-config port))
          'replace))))

  ;; ================================================================
  ;; Remote Entry Accessors
  ;; ================================================================

  (define store-remote-entry-url
    (lambda (entry)
      (cdr (assq 'url (cdr entry)))))

  (define store-remote-entry-path
    (lambda (entry)
      (let ((url (store-remote-entry-url entry)))
        (if (and (>= (string-length url) 7)
                 (string=? (substring url 0 7) "file://"))
            (substring url 7 (string-length url))
            (error 'store-remote-entry-path
                   "remote transport not yet supported" url)))))

  (define store-remote-entry-read-only?
    (lambda (entry)
      (let ((ro (assq 'read-only (cdr entry))))
        (if ro (cdr ro) #f))))

  ;; ================================================================
  ;; Cross-store Copy
  ;; ================================================================

  (define store-copy-directory!
    (lambda (source destination)
      (when (file-exists? source)
        (store-ensure-directory destination)
        (for-each
         (lambda (entry)
           (let ((source-path (store-path-join source entry))
                 (destination-path (store-path-join destination entry)))
             (if (file-directory? source-path)
                 (store-copy-directory! source-path destination-path)
                 (unless (file-exists? destination-path)
                   (let ((content (call-with-port
                                   (open-input-file source-path)
                                   get-string-all)))
                     (call-with-output-file destination-path
                       (lambda (port) (display content port))))))))
         (directory-list source)))))

  (define store-delete-directory!
    (lambda (directory)
      (when (file-exists? directory)
        (for-each
         (lambda (entry)
           (let ((path (store-path-join directory entry)))
             (if (file-directory? path)
                 (store-delete-directory! path)
                 (delete-file path))))
         (directory-list directory))
        (delete-directory directory))))

  (define store-copy-combiner!
    (lambda (source-root destination-root function-hash)
      (let* ((source-directory (store-combiner-directory source-root function-hash))
             (destination-directory (store-combiner-directory destination-root function-hash)))
        (store-copy-directory! source-directory destination-directory))))

  ;; ================================================================
  ;; OpenTimestamps (mock)
  ;; ================================================================

  ;; Create a pending proof file for the given artifact.
  ;; No-op if .pending.proof or .ack.proof already exists.
  (define store-timestamp-request!
    (lambda (filepath)
      (let ((pending-path (string-append filepath ".pending.proof"))
            (ack-path (string-append filepath ".ack.proof")))
        (if (or (file-exists? pending-path) (file-exists? ack-path))
            #f
            (begin
              (let ((content (format #f "(pending ~s ~s)\n"
                                     filepath (store-current-iso-timestamp))))
                (call-with-output-file pending-path
                  (lambda (port) (display content port))))
              #t)))))

  ;; Upgrade a pending proof to an acknowledged proof.
  ;; Creates .ack.proof and deletes .pending.proof.
  ;; No-op if .ack.proof already exists.
  (define store-timestamp-upgrade!
    (lambda (filepath)
      (let ((pending-path (string-append filepath ".pending.proof"))
            (ack-path (string-append filepath ".ack.proof")))
        (unless (file-exists? ack-path)
          (let ((content (format #f "(ack ~s ~s)\n"
                                 filepath (store-current-iso-timestamp))))
            (call-with-output-file ack-path
              (lambda (port) (display content port))))
          (when (file-exists? pending-path)
            (delete-file pending-path))
          #t))))

  ;; Timestamp all committed artifacts for a combiner.
  ;; Returns count of new proofs created.
  (define store-timestamp-combiner!
    (lambda (root function-hash)
      (let ((count 0))
        (define (stamp! filepath)
          (when (store-timestamp-request! filepath)
            (set! count (+ count 1)))
          (store-timestamp-upgrade! filepath))
        ;; 1. tree.scm
        (let ((tree-path (store-combiner-tree-path root function-hash)))
          (when (file-exists? tree-path)
            (stamp! tree-path)))
        ;; 2. All mappings
        (let ((mappings-directory (store-path-join (store-combiner-directory root function-hash)
                                       "mappings")))
          (for-each stamp! (store-find-all-map-files mappings-directory)))
        ;; 3. All committed lineage files
        (let ((lineage-directory (store-path-join (store-combiner-directory root function-hash)
                                       "lineage")))
          (when (file-exists? lineage-directory)
            (for-each
             (lambda (f)
               (when (store-string-suffix? ".committed.scm" f)
                 (stamp! (store-path-join lineage-directory f))))
             (directory-list lineage-directory))))
        count)))

  ;; ================================================================
  ;; Tests
  ;; ================================================================

  (define ~check-store-path-join
    (lambda ()
      (assert (equal? "a/b/c" (store-path-join "a" "b" "c")))
      (assert (equal? "/root/combiners" (store-path-join "/root" "combiners")))))

  (define ~check-store-hash-split-path
    (lambda ()
      (let* ((hash "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678")
             (directory (store-combiner-directory "/store" hash)))
        (assert (equal? "/store/combiners/deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
                         directory)))))

  (define ~check-store-wip-lineage
    (lambda ()
      (let* ((temp (format #f "/tmp/bb-wip-test-~a" (random 1000000)))
             (hash "aabbccdd11223344556677889900aabbccddeeff11223344556677889900aabb"))
        (mkdir temp)
        (let ((directory (store-combiner-directory temp hash)))
          (store-ensure-directory directory)
          (call-with-output-file (store-path-join directory "tree.scm")
            (lambda (p) (display "((body . test))" p)))
          ;; Record wip lineage
          (store-record-wip-lineage! temp hash "tester" "add")
          (assert (pair? (store-list-wip-files temp hash)))
          (assert (not (store-has-committed-lineage? temp hash)))
          ;; Record committed lineage
          (store-record-lineage! temp hash "tester" "commit")
          (assert (store-has-committed-lineage? temp hash))
          ;; Cleanup
          (store-delete-directory! temp)))))

  (define ~check-store-worklog
    (lambda ()
      (let* ((temp (format #f "/tmp/bb-worklog-test-~a" (random 1000000)))
             (hash "aabbccdd11223344556677889900aabbccddeeff11223344556677889900aabb"))
        (mkdir temp)
        (store-add-worklog-entry! temp hash "initial implementation")
        (let ((entries (store-list-worklog-entries temp hash)))
          (assert (= 1 (length entries)))
          (assert (equal? "initial implementation"
                          (cdr (assq 'message (car entries))))))
        (store-delete-directory! temp))))

  (define ~check-store-review
    (lambda ()
      (let* ((temp (format #f "/tmp/bb-review-test-~a" (random 1000000)))
             (hash "aabbccdd11223344556677889900aabbccddeeff11223344556677889900aabb"))
        (mkdir temp)
        (assert (not (store-is-reviewed? temp hash)))
        (store-mark-reviewed! temp hash "alice")
        (assert (store-is-reviewed? temp hash))
        (let ((review (store-load-review temp hash)))
          (assert (equal? "alice" (cdr (assq 'reviewer review)))))
        (store-delete-directory! temp))))

  (define ~check-store-short-hash
    (lambda ()
      ;; Minimum 6 chars
      (let* ((hashes '("aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44"
                        "bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55"))
             (short (store-make-short-hash hashes)))
        (assert (>= (string-length (short (car hashes))) 6))
        (assert (>= (string-length (short (cadr hashes))) 6))
        ;; Both prefixes differ at char 0, so min length 6
        (assert (string=? (short (car hashes)) "aa11bb"))
        (assert (string=? (short (cadr hashes)) "bb22cc")))
      ;; Shared prefix forces longer output
      (let* ((hashes '("aabbcc112233445566778899aabbcc112233445566778899aabbcc1122334455"
                        "aabbcc992233445566778899aabbcc112233445566778899aabbcc1122334455"))
             (short (store-make-short-hash hashes)))
        ;; Both share "aabbcc" prefix, need 7 chars to distinguish
        (assert (>= (string-length (short (car hashes))) 7))
        (assert (not (string=? (short (car hashes))
                               (short (cadr hashes))))))
      ;; Single hash still gets min 6
      (let* ((hashes '("ff00112233445566778899aabbccddeeff00112233445566778899aabbccddee"))
             (short (store-make-short-hash hashes)))
        (assert (string=? (short (car hashes)) "ff0011")))))

  (define ~check-store-validate
    (lambda ()
      (let* ((temp (format #f "/tmp/bb-validate-test-~a" (random 1000000))))
        (mkdir temp)
        (assert (null? (store-list-all-stored-hashes temp)))
        (let* ((body '(lambda (x) (+ x 1)))
               (serialized (scheme-write-value body))
               (hash (sha256-string serialized)))
          (store-combiner! temp hash body)
          (let ((hashes (store-list-all-stored-hashes temp)))
            (assert (= 1 (length hashes)))
            (assert (equal? hash (car hashes)))))
        (store-delete-directory! temp))))

  (define ~check-store-load-checks
    (lambda ()
      (let* ((temp (format #f "/tmp/bb-checks-test-~a" (random 1000000)))
             (main-body '(lambda (x) (+ x 1)))
             (main-serialized (scheme-write-value main-body))
             (main-hash (sha256-string main-serialized))
             (check-body1 '(lambda () (assert (= 2 (+ 1 1)))))
             (check-serialized1 (scheme-write-value check-body1))
             (check-hash1 (sha256-string check-serialized1))
             (check-body2 '(lambda () (assert (= 4 (+ 2 2)))))
             (check-serialized2 (scheme-write-value check-body2))
             (check-hash2 (sha256-string check-serialized2))
             (check-body3 '(lambda () (assert (= 9 (+ 4 5)))))
             (check-serialized3 (scheme-write-value check-body3))
             (check-hash3 (sha256-string check-serialized3)))
        (mkdir temp)
        (store-combiner! temp main-hash main-body)
        (store-combiner! temp check-hash1 check-body1)
        (store-combiner! temp check-hash2 check-body2)
        (store-combiner! temp check-hash3 check-body3)
        ;; No checks yet
        (assert (null? (store-load-checks-for-combiner temp main-hash)))
        ;; Alice adds check1 and check2 at T1
        (store-record-wip-lineage! temp main-hash "alice" "add" #f #f
                             (list check-hash1 check-hash2))
        ;; Bob adds check3 independently at T1 (same second — retract-on-tie test later)
        (store-record-wip-lineage! temp main-hash "bob" "add" #f #f
                             (list check-hash3))
        ;; All three should appear (union)
        (let ((checks (store-load-checks-for-combiner temp main-hash)))
          (assert (= 3 (length checks)))
          (assert (member check-hash1 checks))
          (assert (member check-hash2 checks))
          (assert (member check-hash3 checks)))
        ;; Alice retracts check2 at T2 > T1 — most recent action is retract, so removed
        (sleep (make-time 'time-duration 0 1))
        (store-record-wip-retract-checks! temp main-hash "alice" (list check-hash2))
        (let ((checks (store-load-checks-for-combiner temp main-hash)))
          (assert (= 2 (length checks)))
          (assert (member check-hash1 checks))
          (assert (not (member check-hash2 checks)))
          (assert (member check-hash3 checks)))
        ;; Alice re-adds check2 at T3 > T2 — most recent is now add again
        (sleep (make-time 'time-duration 0 1))
        (store-record-wip-lineage! temp main-hash "alice" "edit" #f #f
                             (list check-hash2))
        (let ((checks (store-load-checks-for-combiner temp main-hash)))
          (assert (= 3 (length checks)))
          (assert (member check-hash1 checks))
          (assert (member check-hash2 checks))
          (assert (member check-hash3 checks)))
        (store-delete-directory! temp))))

  (define ~check-store-timestamp
    (lambda ()
      (let* ((temp (format #f "/tmp/bb-timestamp-test-~a" (random 1000000)))
             (body '(lambda (x) (+ x 1)))
             (serialized (scheme-write-value body))
             (hash (sha256-string serialized)))
        (mkdir temp)
        ;; Store a combiner with tree, mapping, and committed lineage
        (store-combiner! temp hash body)
        (store-mapping! temp hash "en"
                        (list (cons 0 "test-fn")) "test combiner")
        (store-record-lineage! temp hash "tester" "add")
        ;; Timestamp all artifacts
        (let ((count (store-timestamp-combiner! temp hash)))
          (assert (> count 0))
          ;; Verify ack.proof files exist
          (let ((tree-path (store-combiner-tree-path temp hash)))
            (assert (file-exists? (string-append tree-path ".ack.proof")))
            (assert (not (file-exists? (string-append tree-path ".pending.proof")))))
          ;; Re-timestamp — should be idempotent (0 new proofs)
          (let ((count2 (store-timestamp-combiner! temp hash)))
            (assert (= 0 count2))))
        (store-delete-directory! temp))))

  )
