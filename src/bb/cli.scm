(library (bb cli)

  (export main
          ~check-cli-build-argument-tree
          ~check-cli-mobius-write-surface
          ~check-cli-replace-ref
          ~check-cli-diff-trees
          ~check-cli-prepare-for-pretty
          ~check-cli-post-process
          ~check-cli-lcs-lines
          ~check-cli-resolve-ref
          ~check-cli-show
          ~check-cli-print
          ~check-cli-doc-roundtrip)

  (import (chezscheme)
          (bb values)
          (bb reader)
          (bb evaluator)
          (bb base-library)
          (bb serialization)
          (bb hash)
          (bb store)
          (bb z3))

  ;; ================================================================
  ;; bb CLI — Mobius Seed evaluator and store manager
  ;;
  ;; Commands:
  ;;   bb run (name|hash) [args...]   — evaluate a combiner
  ;;   bb add name file               — parse, store, bind (wip)
  ;;   bb add --check <combiner> <check> — register check for combiner
  ;;   bb commit [name... | --all]    — promote wip to committed
  ;;   bb edit (name|hash)            — open in $EDITOR, re-add on save
  ;;   bb diff name1 name2            — structural comparison
  ;;   bb refactor root old new [at]  — propagate hash changes
  ;;   bb review (name|hash)          — mark as reviewed
  ;;   bb search query                — search combiners
  ;;   bb worklog (name|hash) [msg]   — time-stamped work log
  ;;   bb validate                    — verify store integrity
  ;;   bb anchor <ref>                — request / upgrade OpenTimestamps proof
  ;;   bb remote add <name> <url>     — add a remote <name> at <url>
  ;;   bb remote remove <name>        — remove remote <name>
  ;;   bb remote list                 — list remotes
  ;;   bb remote push <name>          — push committed combiners to remote
  ;;   bb remote pull <name>          — pull committed combiners from remote
  ;;   bb remote sync                 — pull and push all remotes
  ;;   bb remote publish <name> <ref> — mark ref public to <name>
  ;;   bb remote stop <name> <ref>    — stop publishing ref to <name>
  ;;   bb repl                        — interactive Seed session
  ;;   bb store init                  — create new mobius-store
  ;;   bb store info                  — show store statistics
  ;;   bb status                      — show working state
  ;;   bb tree (name|hash)            — dependency DAG
  ;;   bb log [(name|hash)]           — timeline
  ;;   bb --help                      — usage
  ;; ================================================================

  ;; ================================================================
  ;; Helpers
  ;; ================================================================

  (define bb-version "0.1.0")

  (define print-usage
    (lambda ()
      (display "bb — Mobius Seed evaluator and store manager\n\n")
      (display "Usage:\n")
      (display "  bb add [--derived-from=<ref>] [--relation=<type>] <file|->\n")
      (display "                                            Parse, normalize, store, and bind\n")
      (display "  bb add --check <combiner> <check>         Register check for combiner\n")
      (display "  bb caller <ref>                         Show reverse dependency DAG\n")
      (display "  bb check <ref>                          Run all checks for ref and its dependencies\n")
      (display "  bb commit [name... | --all]             Promote staged combiners to committed\n")
      (display "  bb diff <ref> <ref>                     Compare two combiners (pretty-printed diff)\n")
      (display "  bb edit <ref> [lang]                    Edit combiner in $EDITOR, re-add on save\n")
      (display "  bb eval <expression>                    Evaluate a single expression\n")
      (display "  bb log [ref]                            Show timeline\n")
      (display "  bb print <ref>                          Output Chez Scheme library with all dependencies\n")
      (display "  bb anchor <ref>                         Request or upgrade OpenTimestamps proof\n")
      (display "  bb refactor <ref> <ref> <ref> [<ref>]   Replace old with new in root tree\n")
      (display "  bb mapping list <ref>                   List all mappings for a combiner\n")
      (display "  bb mapping delete <ref>                 Delete a mapping (ref must include mapping hash)\n")
      (display "  bb mapping set <ref> <key> <value>      Set a mapping entry (0=name, 1+=params)\n")
      (display "  bb remote add <name> <path>             Add a remote store endpoint\n")
      (display "  bb remote list                          List configured remote store endpoints\n")
      (display "  bb remote remove <name>                 Remove a remote store endpoint\n")
      (display "  bb remote push <name>                   Push committed combiners to remote\n")
      (display "  bb remote pull <name>                   Pull committed combiners from remote\n")
      (display "  bb remote sync                          Pull and push all configured remotes\n")
      (display "  bb remote publish <name> <ref>          Mark ref (and closure) public to <name>\n")
      (display "  bb remote stop <name> <ref>             Stop publishing ref to <name>\n")
      (display "  bb repl                                 Interactive Seed session\n")
      (display "  bb resolve <ref>                        Resolve ref to full spec\n")
      (display "  bb review <ref>                         Mark combiner as reviewed\n")
      (display "  bb run <ref> [args...]                  Evaluate a registered combiner\n")
      (display "  bb search <query>                       Search combiner names and content\n")
      (display "  bb show <ref>                           Display combiner doc and definition\n")
      (display "  bb status                               Show working state\n")
      (display "  bb store info                           Show store statistics\n")
      (display "  bb store init                           Create a new mobius-store\n")
      (display "  bb tree <ref>                           Show dependency DAG\n")
      (display "  bb validate                             Verify store integrity\n")
      (display "  bb worklog <ref> [msg]                  View or add work log entries\n")
      (display "  bb --help                               Show this help\n")
      (display "  bb --version                            Show version\n")
      (display "\nVersion: ")
      (display bb-version)
      (display "\n")))

  ;; ================================================================
  ;; bb eval — evaluate a single expression
  ;; ================================================================

  (define command-eval
    (lambda (arguments)
      (when (null? arguments)
        (display "bb eval: missing expression\n" (current-error-port))
        (exit 1))
      (let* ((source (car arguments))
             (environment (install-base-library (make-initial-environment)))
             (expressions (mobius-read-all-string source)))
        (let-values (((final-environment value)
                      (mobius-eval-top-level expressions environment)))
          (mobius-display-value value)
          (newline)))))

  ;; Print a value in a readable format
  (define mobius-display-value
    (lambda (value)
      (cond
       ((mobius-nil? value) (display "#nil"))
       ((mobius-void? value) (display "#void"))
       ((mobius-eof? value) (display "#eof"))
       ((boolean? value) (display (if value "#true" "#false")))
       ((string? value) (write value))
       ((char? value) (display "#\\") (display value))
       ((integer? value) (display value))
       ((flonum? value) (display value))
       ((pair? value)
        (display "(")
        (mobius-display-value (car value))
        (let loop ((tail (cdr value)))
          (cond
           ((mobius-nil? tail) (display ")"))
           ((pair? tail)
            (display " ")
            (mobius-display-value (car tail))
            (loop (cdr tail)))
           (else
            (display " . ")
            (mobius-display-value tail)
            (display ")")))))
       ((mobius-user-combiner? value)
        (display "#<combiner")
        (let ((name (mobius-combiner-name value)))
          (when name
            (display " ")
            (display name)))
        (display ">"))
       (else (display value)))))

  ;; Write a denormalized surface expression in Mobius syntax
  (define mobius-write-surface
    (lambda (expression)
      (cond
       ((mobius-nil? expression) (display "#nil"))
       ((mobius-void? expression) (display "#void"))
       ((mobius-eof? expression) (display "#eof"))
       ((boolean? expression) (display (if expression "#true" "#false")))
       ((string? expression) (write expression))
       ((char? expression) (display "#\\") (display expression))
       ((integer? expression) (display expression))
       ((flonum? expression) (display expression))
       ((symbol? expression) (display (symbol->string expression)))
       ;; Pattern bind: (mobius-unquote x) => ,x
       ((and (pair? expression) (eq? 'mobius-unquote (car expression)))
        (let ((name (cadr expression)))
          (if (eq? name '_)
              (display ",_")
              (begin (display ",") (display (symbol->string name))))))
       ;; Catamorphic bind: (mobius-unquote-recurse x) => ,(x)
       ((and (pair? expression) (eq? 'mobius-unquote-recurse (car expression)))
        (display ",(")
        (display (symbol->string (cadr expression)))
        (display ")"))
       ;; Pair/list
       ((pair? expression)
        (display "(")
        (mobius-write-surface (car expression))
        (let loop ((tail (cdr expression)))
          (cond
           ((null? tail) (display ")"))
           ((pair? tail)
            (display " ")
            (mobius-write-surface (car tail))
            (loop (cdr tail)))
           (else
            (display " . ")
            (mobius-write-surface tail)
            (display ")")))))
       (else (display expression)))))

  ;; ================================================================
  ;; bb repl — interactive Seed session
  ;; ================================================================

  (define command-repl
    (lambda ()
      (display "bb repl — Mobius Seed v")
      (display bb-version)
      (display "\nType expressions to evaluate. Ctrl-D to exit.\n\n")
      (let* ((base-environment (install-base-library (make-initial-environment)))
             (environment (guard (condition (#t base-environment))
                    (let* ((root (store-find-root (current-directory)))
                           (name-index (store-build-name-index root)))
                      (display "Loading store combiners...\n")
                      (let ((loaded (load-index-into-env name-index root base-environment)))
                        (display (length name-index))
                        (display " combiner(s) loaded.\n\n")
                        loaded)))))
        (let loop ((environment environment))
          (display "bb> ")
          (flush-output-port (current-output-port))
          (let ((input (read-line (current-input-port))))
            (cond
             ((eof-object? input)
              (newline)
              (display "Goodbye.\n"))
             ((string=? (string-trim input) "")
              (loop environment))
             (else
              (guard (condition
                      (#t
                       (display "Error: " (current-error-port))
                       (display-condition condition (current-error-port))
                       (newline (current-error-port))
                       (loop environment)))
                (let* ((expressions (mobius-read-all-string input)))
                  (let-values (((new-environment value)
                                (mobius-eval-top-level expressions environment)))
                    (unless (mobius-void? value)
                      (mobius-display-value value)
                      (newline))
                    (loop new-environment)))))))))))

  (define string-trim
    (lambda (string)
      (let* ((length (string-length string))
             (start (let loop ((index 0))
                      (if (and (< index length)
                               (char-whitespace? (string-ref string index)))
                          (loop (+ index 1))
                          index)))
             (end (let loop ((index length))
                    (if (and (> index start)
                             (char-whitespace? (string-ref string (- index 1))))
                        (loop (- index 1))
                        index))))
        (substring string start end))))

  (define read-line
    (lambda (port)
      (let loop ((characters '()))
        (let ((char (read-char port)))
          (cond
           ((eof-object? char)
            (if (null? characters) char (list->string (reverse characters))))
           ((char=? char #\newline)
            (list->string (reverse characters)))
           (else
            (loop (cons char characters))))))))

  (define string-contains?
    (lambda (haystack needle)
      (let ((h-len (string-length haystack))
            (n-len (string-length needle)))
        (let loop ((i 0))
          (cond
           ((> (+ i n-len) h-len) #f)
           ((string=? (substring haystack i (+ i n-len)) needle) #t)
           (else (loop (+ i 1))))))))

  (define resolve-hash-only
    (lambda (root hash-prefix)
      (let* ((all-hashes (store-list-all-stored-hashes root))
             (prefix-len (string-length hash-prefix))
             (matches (filter (lambda (h)
                                (and (>= (string-length h) prefix-len)
                                     (string=? (substring h 0 prefix-len) hash-prefix)))
                              all-hashes)))
        (cond
         ((= (length matches) 1) (car matches))
         ((null? matches)
          (error 'resolve "combiner not found" hash-prefix))
         (else
          (error 'resolve "ambiguous hash prefix" hash-prefix matches))))))

  (define string-split-at-sign
    (lambda (s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond
         ((= i (string-length s))
          (reverse (cons (substring s start i) acc)))
         ((char=? (string-ref s i) (string-ref "@" 0))
          (loop (+ i 1) (+ i 1)
                (cons (substring s start i) acc)))
         (else (loop (+ i 1) start acc))))))

  ;; Heuristic: is a string likely a language code (not a hex hash prefix)?
  ;; Languages are short alphabetic strings like "en", "fr", "kab".
  ;; Hash prefixes are hex strings.
  (define looks-like-lang?
    (lambda (s)
      (and (>= (string-length s) 2)
           (<= (string-length s) 4)
           (for-all char-alphabetic?
                    (string->list s)))))

  ;; Resolve a single identifier (name or hash prefix) to a full hash.
  ;; Checks name-index first, then hash prefix match.
  (define resolve-name-to-hash
    (lambda (name-index root name)
      (let ((entry (assoc name name-index)))
        (if entry
            (cdr entry)
            ;; Check for disambiguated names matching name@...
            (let ((prefix (string-append name "@")))
              (let ((name-matches (filter (lambda (e)
                                            (let ((k (car e)))
                                              (and (> (string-length k) (string-length prefix))
                                                   (string=? (substring k 0 (string-length prefix))
                                                             prefix))))
                                          name-index)))
                (cond
                 ((= (length name-matches) 1)
                  (cdar name-matches))
                 ((> (length name-matches) 1)
                  ;; Pick the combiner with the most recent lineage timestamp
                  (let loop ((remaining name-matches) (best-hash #f) (best-ts #f))
                    (if (null? remaining)
                        (or best-hash (cdar name-matches))
                        (let* ((h (cdar remaining))
                               (ts (store-combiner-latest-timestamp root h)))
                          (if (and ts (or (not best-ts) (string>? ts best-ts)))
                              (loop (cdr remaining) h ts)
                              (loop (cdr remaining) best-hash best-ts))))))
                 (else
                  ;; Try hash prefix match
                  (resolve-hash-only root name)))))))))

  ;; Resolve a <ref> string to (values combiner-hash lang-or-#f mapping-hash-prefix-or-#f).
  ;;
  ;; Ref format: name@combinerShortHash@lang@mappingShortHash
  ;; 1 part:  name or combinerShortHash
  ;; 2 parts: name@lang, combinerShortHash@lang, combinerShortHash@mappingShortHash
  ;; 3 parts: name@combinerShortHash@lang, name@lang@mappingShortHash
  ;; 4 parts: name@combinerShortHash@lang@mappingShortHash
  (define resolve-ref
    (lambda (name-index root ref-string)
      (let ((parts (string-split-at-sign ref-string)))
        (cond
         ;; 1 part: name or hash
         ((= (length parts) 1)
          (values (resolve-name-to-hash name-index root (car parts)) #f #f))

         ;; 2 parts: name@lang, name@disambiguator, hash@lang, hash@mappingHash
         ;; First try the full ref-string as a disambiguated name in the index.
         ((= (length parts) 2)
          (let ((part1 (car parts))
                (part2 (cadr parts)))
            (let ((full-entry (assoc ref-string name-index)))
              (if full-entry
                  ;; Exact match on "name@hash" disambiguated entry
                  (values (cdr full-entry) #f #f)
                  ;; Check if part1 is a name (exact or disambiguated) in the index
                  (let ((name-entry (assoc part1 name-index))
                        (has-disambiguated
                         (let ((prefix (string-append part1 "@")))
                           (exists (lambda (e)
                                     (let ((k (car e)))
                                       (and (> (string-length k) (string-length prefix))
                                            (string=? (substring k 0 (string-length prefix))
                                                      prefix))))
                                   name-index))))
                    (if (or name-entry has-disambiguated)
                        ;; part1 is a name -> part2 is lang
                        (values (resolve-name-to-hash name-index root part1) part2 #f)
                        ;; part1 is a hash prefix
                        (let ((combiner-hash (resolve-hash-only root part1)))
                          (if (looks-like-lang? part2)
                              ;; hash@lang
                              (values combiner-hash part2 #f)
                              ;; hash@mappingHash
                              (values combiner-hash #f part2)))))))))

         ;; 3 parts: name@combinerShortHash@lang or name@lang@mappingShortHash
         ((= (length parts) 3)
          (let ((part1 (car parts))
                (part2 (cadr parts))
                (part3 (caddr parts)))
            (if (looks-like-lang? part2)
                ;; name@lang@mappingShortHash
                (values (resolve-name-to-hash name-index root part1) part2 part3)
                ;; name@combinerShortHash@lang
                (values (resolve-hash-only root part2) part3 #f))))

         ;; 4 parts: name@combinerShortHash@lang@mappingShortHash
         ((= (length parts) 4)
          (let ((part2 (cadr parts))
                (part3 (caddr parts))
                (part4 (cadddr parts)))
            (values (resolve-hash-only root part2) part3 part4)))

         (else
          (error 'resolve-ref "invalid ref format" ref-string))))))

  ;; Resolve a mapping using the lang/mapping-prefix constraints from resolve-ref.
  ;; Returns map-data suitable for show-combiner-with-mapping etc.
  (define resolve-ref-mapping
    (lambda (root function-hash lang mapping-prefix)
      (cond
       ;; Exact mapping hash prefix specified
       (mapping-prefix
        (let* ((mappings-dir (store-path-join (store-combiner-directory root function-hash) "mappings"))
               (map-files (store-find-all-map-files mappings-dir))
               (all-hashes (store-list-all-stored-hashes root))
               (short-hash (store-make-short-hash all-hashes)))
          (let loop ((remaining map-files))
            (if (null? remaining)
                (error 'resolve-ref-mapping "mapping not found" mapping-prefix)
                (guard (exn (#t (loop (cdr remaining))))
                  (let* ((content (call-with-input-file (car remaining) get-string-all))
                         (mapping-hash (sha256-string content))
                         (map-data (read (open-input-string content)))
                         (sh (short-hash mapping-hash))
                         (prefix-len (string-length mapping-prefix)))
                    ;; Match against short hash or full hash
                    (if (or (and (>= (string-length sh) prefix-len)
                                (string=? (substring sh 0 prefix-len) mapping-prefix))
                            (and (>= (string-length mapping-hash) prefix-len)
                                 (string=? (substring mapping-hash 0 prefix-len) mapping-prefix)))
                        ;; If lang is also specified, verify it matches
                        (if (or (not lang)
                                (let ((lang-entry (assq 'language map-data)))
                                  (and lang-entry (string=? (cdr lang-entry) lang))))
                            map-data
                            (loop (cdr remaining)))
                        (loop (cdr remaining)))))))))
       ;; Language specified but no mapping prefix
       (lang
        (store-load-mapping-by-language root function-hash lang))
       ;; Neither -> use preferred mapping
       (else
        (store-load-preferred-mapping root function-hash)))))

  ;; ================================================================
  ;; Name lookup helper — resolves a symbol to its content hash
  ;; using the name-index and ref resolution.
  ;; ================================================================

  (define make-name-lookup
    (lambda (name-index root)
      (lambda (sym)
        (let ((name-str (symbol->string sym)))
          (let ((entry (assoc name-str name-index)))
            (if entry
                (cdr entry)
                ;; Try ref resolution for name@hash@lang@map style refs
                (guard (exn (#t #f))
                  (let-values (((h l m) (resolve-ref name-index root name-str)))
                    h))))))))

  ;; ================================================================
  ;; bb add — parse, normalize, store, bind (wip lineage)
  ;; ================================================================

  (define command-add
    (lambda (arguments)
      (when (null? arguments)
        (display "bb add: usage: bb add [--derived-from=<ref>] [--relation=<type>] <file|->\n" (current-error-port))
        (display "       bb add --check <combiner> <check>\n" (current-error-port))
        (exit 1))
      ;; --check mode: associate an existing check with an existing combiner
      (when (string=? (car arguments) "--check")
        (let ((rest (cdr arguments)))
          (when (< (length rest) 2)
            (display "bb add --check: usage: bb add --check <combiner> <check>\n"
                     (current-error-port))
            (exit 1))
          (let* ((combiner-ref (car rest))
                 (check-ref (cadr rest))
                 (root (store-find-root (current-directory)))
                 (name-index (store-build-name-index root))
                 (combiner-hash
                  (let-values (((h l m) (resolve-ref name-index root combiner-ref))) h))
                 (check-hash
                  (let-values (((h l m) (resolve-ref name-index root check-ref))) h))
                 (existing-checks (store-load-checks root combiner-hash))
                 (author (store-config-author root)))
            (if (member check-hash existing-checks)
                (begin
                  (display "already registered: ")
                  (display check-ref)
                  (display " is a check of ")
                  (display combiner-ref)
                  (display "\n"))
                (let ((new-checks (append existing-checks (list check-hash))))
                  (store-record-wip-lineage! root combiner-hash author "add"
                                             #f #f new-checks)
                  (display "check added: ")
                  (display check-ref)
                  (display " -> ")
                  (display combiner-ref)
                  (display "\n"))))
          (exit 0)))
      ;; Extract --derived-from=<ref> and --relation=<type> flags
      (let* ((derived-from-raw
              (let loop ((remaining arguments))
                (cond
                 ((null? remaining) #f)
                 ((and (>= (string-length (car remaining)) 15)
                       (string=? (substring (car remaining) 0 15) "--derived-from="))
                  (substring (car remaining) 15 (string-length (car remaining))))
                 (else (loop (cdr remaining))))))
             (relation-raw
              (let loop ((remaining arguments))
                (cond
                 ((null? remaining) #f)
                 ((and (>= (string-length (car remaining)) 11)
                       (string=? (substring (car remaining) 0 11) "--relation="))
                  (substring (car remaining) 11 (string-length (car remaining))))
                 (else (loop (cdr remaining))))))
             (positional
              (filter (lambda (a)
                        (not (or (and (>= (string-length a) 15)
                                      (string=? (substring a 0 15) "--derived-from="))
                                 (and (>= (string-length a) 11)
                                      (string=? (substring a 0 11) "--relation=")))))
                      arguments))
             (allowed-relations '("fork" "fix" "refine" "translate" "extend" "rewrite"))
             (relation (cond
                        (relation-raw
                         (unless (member relation-raw allowed-relations)
                           (display (string-append "bb add: invalid relation '" relation-raw
                                                   "'. Must be one of: fork fix refine translate extend rewrite\n")
                                    (current-error-port))
                           (exit 1))
                         relation-raw)
                        (derived-from-raw "fork")
                        (else "add"))))
        (when (null? positional)
          (display "bb add: usage: bb add [--derived-from=<ref>] [--relation=<type>] <file|->\n" (current-error-port))
          (exit 1))
      (let* ((file (car positional))
             (root (store-find-root (current-directory)))
             (default-lang (guard (exn (#t "en"))
                             (car (store-config-languages root))))
             (lang (if (null? (cdr positional)) default-lang (cadr positional)))
             (source (if (string=? file "-")
                         (get-string-all (current-input-port))
                         (call-with-input-file file get-string-all)))
             (name-index (store-build-name-index root))
             (derived-from-hash
              (and derived-from-raw
                   (guard (exn (#t
                                (display (string-append "bb add: cannot resolve --derived-from ref '"
                                                        derived-from-raw "'\n")
                                         (current-error-port))
                                (exit 1)))
                     (let-values (((h l m) (resolve-ref name-index root derived-from-raw)))
                       h))))
             (doc (source-extract-doc source))
             (environment (install-base-library (make-initial-environment))))
        ;; Load existing combiners into environment
        (let ((environment (load-index-into-env name-index root environment)))
          ;; Parse expressions
          (let* ((expressions (mobius-read-all-string source))
                 (author (store-config-author root))
                 (name-lookup (make-name-lookup name-index root)))
            ;; Evaluate to verify correctness
            (let-values (((final-environment last-value)
                          (mobius-eval-top-level expressions environment)))
              ;; Classify into main and check defines
              (let-values (((main-defines check-defines) (classify-defines expressions)))
                (set! name-index
                  (edit-store-all! root name-index lang doc main-defines
                                   check-defines name-lookup author
                                   derived-from-hash relation))
                (display "Done. Use 'bb commit' to finalize.\n")))))))))

  ;; Build a hash->name reverse lookup from a name-index and store.
  ;; First checks the index, then falls back to reading the stored mapping.
  (define make-hash->name
    (lambda (name-index root)
      (lambda (hash)
        (let loop ((remaining name-index))
          (if (null? remaining)
              ;; Not in index — try loading name from store mapping
              (guard (exn (#t #f))
                (let* ((map-data (store-load-first-mapping root hash))
                       (mapping (cdr (assq 'mapping map-data)))
                       (name-entry (assv 0 mapping)))
                  (if name-entry
                      (string->symbol (cdr name-entry))
                      #f)))
              (if (string=? hash (cdar remaining))
                  (string->symbol (caar remaining))
                  (loop (cdr remaining))))))))

  ;; Load a single combiner from the store, denormalize, and evaluate.
  ;; Use the preferred-language mapping so that the denormalized body's
  ;; free-variable references (and the combiner's self-name in recursive
  ;; calls) resolve against names actually present in the name index,
  ;; which is also built from preferred-language mappings.
  (define load-combiner-value
    (lambda (root function-hash hash->name environment)
      (let* ((body (store-load-combiner root function-hash))
             (map-data (store-load-preferred-mapping root function-hash))
             (mapping (cdr (assq 'mapping map-data)))
             (surface (denormalize-tree body mapping hash->name)))
        (mobius-eval surface environment))))

  ;; Load name-index entries into evaluation environment
  (define load-index-into-env
    (lambda (name-index root environment)
      (let ((hash->name (make-hash->name name-index root)))
        ;; Pre-bind all names to #void for mutual references
        (let ((environment (let loop ((remaining name-index) (environment environment))
                     (if (null? remaining)
                         environment
                         (loop (cdr remaining)
                               (name-environment-extend environment
                                                (string->symbol (caar remaining))
                                                mobius-void))))))
          ;; Load each combiner and update bindings
          ;; Skip combiners that fail to load (e.g. referencing removed primitives)
          (for-each
           (lambda (entry)
             (guard (exn (#t (void)))  ;; leave pre-bound #void on failure
               (let* ((name (string->symbol (car entry)))
                      (function-hash (cdr entry))
                      (value (load-combiner-value root function-hash
                                                  hash->name environment))
                      ;; Assign name for self-reference
                      (value (if (and (mobius-user-combiner? value)
                                      (not (mobius-combiner-name value)))
                                 (make-mobius-combiner
                                  (mobius-combiner-clauses value)
                                  (mobius-combiner-environment value)
                                  name)
                                 value)))
                 (name-environment-set! environment name value))))
           name-index)
          environment))))

  ;; ================================================================
  ;; bb store init — create new mobius-store
  ;; ================================================================

  (define command-store-init
    (lambda (arguments)
      (let ((directory (if (null? arguments)
                           (current-directory)
                           (car arguments))))
        ;; Create directories
        (for-each
         (lambda (subdirectory)
           (let ((path (store-path-join directory subdirectory)))
             (unless (file-exists? path)
               (store-ensure-directory path))))
         '("combiners" "reviewed" "worklog"))
        ;; Create config.scm
        (let ((config-path (store-path-join directory "config.scm")))
          (unless (file-exists? config-path)
            (call-with-output-file config-path
              (lambda (port)
                (display "((author\n" port)
                (display "   ((email . \"\")\n" port)
                (display "    (languages . (\"en\"))\n" port)
                (display "    (name . \"\")\n" port)
                (display "    (website . \"\")))\n" port)
                (display " (remotes . ()))\n" port)))))
        ;; Create .gitignore
        (let ((gitignore-path (store-path-join directory ".gitignore")))
          (unless (file-exists? gitignore-path)
            (call-with-output-file gitignore-path
              (lambda (port)
                (display ".bb-ann\n" port)
                (display "remotes/\n" port)
                (display "combiners/**/lineage/*.wip.scm\n" port)))))
        (display "Initialized mobius store at ")
        (display directory)
        (display "\n"))))

  ;; ================================================================
  ;; bb store info — show store statistics
  ;; ================================================================

  (define command-store-info
    (lambda ()
      (let* ((root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (short-hash (store-make-short-hash (store-list-all-stored-hashes root))))
        (display "Store: ")
        (display root)
        (newline)
        (display "Named combiners: ")
        (display (length name-index))
        (newline)
        (for-each
         (lambda (entry)
           (display "  ")
           (display (car entry))
           (display " -> ")
           (display (short-hash (cdr entry)))
           (display "\n"))
         name-index))))

  ;; ================================================================
  ;; bb status — show working state
  ;; ================================================================

  ;; Anchor status of a combiner. Returns 'anchored (final .ots present),
  ;; 'pending (only .ots.pending present), or #f (neither).
  (define combiner-anchor-status
    (lambda (root function-hash)
      (let ((tree-path (store-combiner-tree-path root function-hash)))
        (cond
         ((file-exists? (string-append tree-path ".ots")) 'anchored)
         ((file-exists? (string-append tree-path ".ots.pending")) 'pending)
         (else #f)))))

  (define command-status
    (lambda ()
      (let* ((root (store-find-root (current-directory)))
             (name-index (store-build-name-index root)))
        (if (null? name-index)
            (display "Empty store. Use 'bb add' to add combiners.\n")
            (begin
              (display (length name-index))
              (display " combiner(s).\n")
              (for-each
               (lambda (entry)
                 (let* ((name (car entry))
                        (fhash (cdr entry))
                        (committed? (store-has-committed-lineage? root fhash))
                        (wip? (pair? (store-list-wip-files root fhash)))
                        (reviewed? (store-is-reviewed? root fhash))
                        (anchor (combiner-anchor-status root fhash))
                        (tags (filter (lambda (t) t)
                                      (list (cond (committed? "committed")
                                                  (wip? "wip")
                                                  (else "unknown"))
                                            (and reviewed? "reviewed")
                                            (case anchor
                                              ((anchored) "anchored")
                                              ((pending) "anchor-pending")
                                              (else #f))))))
                   (display "  ")
                   (display name)
                   (display "  [")
                   (let loop ((ts tags) (first? #t))
                     (unless (null? ts)
                       (unless first? (display ", "))
                       (display (car ts))
                       (loop (cdr ts) #f)))
                   (display "]")
                   (newline)))
               name-index))))))

  ;; ================================================================
  ;; bb tree — show dependency DAG downward
  ;; ================================================================

  ;; Extract all mobius-constant-ref hashes from a normalized tree
  (define extract-refs
    (lambda (tree)
      (cond
       ((not (pair? tree)) '())
       ((and (eq? 'mobius-constant-ref (car tree))
             (pair? (cdr tree))
             (string? (cadr tree)))
        (list (cadr tree)))
       (else
        (append (extract-refs (car tree))
                (extract-refs (cdr tree)))))))

  ;; Find shortest prefix of hash that is unique within group.
  (define shortest-unique-prefix
    (lambda (h group)
      (let loop ((prefix-length 4))
        (let ((prefix (substring h 0 (min prefix-length (string-length h)))))
          (if (= 1 (length (filter (lambda (gh)
                                     (and (>= (string-length gh) prefix-length)
                                          (string=? prefix
                                                    (substring gh 0 prefix-length))))
                                   group)))
              prefix
              (loop (+ prefix-length 1)))))))

  (define command-print
    (lambda (arguments)
      (when (null? arguments)
        (display "bb print: missing name or hash\n" (current-error-port))
        (exit 1))
      (let* ((name (car arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (hash (let-values (((h l m) (resolve-ref name-index root name))) h))
             (hash->name (make-hash->name name-index root))
             ;; Resolve a display name for the root combiner
             (root-name
              (let ((entry (find (lambda (e) (string=? (cdr e) hash)) name-index)))
                (if entry
                    (car entry)
                    (let ((sym (hash->name hash)))
                      (if sym (symbol->string sym) name))))))
        ;; Collect all dependencies in topological (post) order via DFS
        (define visited (make-hashtable string-hash string=?))
        (define order '())
        (define collect!
          (lambda (h)
            (unless (hashtable-ref visited h #f)
              (hashtable-set! visited h #t)
              (guard (exn (#t #t))  ;; skip if load fails
                (let* ((body (store-load-combiner root h))
                       (deps (extract-refs body))
                       ;; Deduplicate deps
                       (seen (make-hashtable string-hash string=?))
                       (unique-deps
                        (filter (lambda (d)
                                  (if (hashtable-ref seen d #f)
                                      #f
                                      (begin (hashtable-set! seen d #t) #t)))
                                deps)))
                  (for-each collect! unique-deps)))
              (set! order (cons h order)))))
        (collect! hash)
        (let* ((ordered (reverse order))
               (short-hash (store-make-short-hash (store-list-all-stored-hashes root))))
          ;; Build base-name for each hash (root → "main", others → mapping name)
          (let* ((hash-names
                  (map (lambda (h)
                         (cons h (if (string=? h hash)
                                     "main"
                                     (let ((sym (hash->name h)))
                                       (if sym
                                           (symbol->string sym)
                                           (string-append
                                            "«" (short-hash h) "»"))))))
                       ordered))
                 ;; Group hashes by base name to detect collisions
                 (name-groups (make-hashtable string-hash string=?)))
            (for-each (lambda (pair)
                        (let* ((n (cdr pair))
                               (existing (hashtable-ref name-groups n '())))
                          (hashtable-set! name-groups n (cons (car pair) existing))))
                      hash-names)
            ;; Build final-names: disambiguate collisions with @<prefix>
            (let ((final-names (make-hashtable string-hash string=?)))
              (for-each
               (lambda (pair)
                 (let* ((h (car pair))
                        (base-name (cdr pair))
                        (group (hashtable-ref name-groups base-name '())))
                   (hashtable-set! final-names h
                                   (if (= (length group) 1)
                                       base-name
                                       (string-append base-name "@"
                                                      (shortest-unique-prefix h group))))))
               hash-names)
              ;; Custom hash->name that uses disambiguation table
              (let ((print-hash->name
                     (lambda (h)
                       (let ((n (hashtable-ref final-names h #f)))
                         (if n
                             (string->symbol n)
                             (hash->name h))))))
              ;; Emit Chez Scheme library
              (display "#!chezscheme\n")
              (display (string-append "(library (" root-name ")\n"))
              (display "\n")
              (display "  (export main)\n")
              (display "\n")
              (display "  (import (chezscheme))\n")
              (for-each
               (lambda (h)
                 (let* ((display-name (hashtable-ref final-names h "??"))
                        (body (store-load-combiner root h))
                        (map-data (store-load-preferred-mapping root h))
                        (mapping (cdr (assq 'mapping map-data)))
                        (surface (denormalize-tree body mapping print-hash->name))
                        (prepared (prepare-for-pretty
                                   (list 'define (string->symbol display-name) surface)))
                        (port (open-output-string)))
                   (parameterize ((pretty-line-length 72))
                     (pretty-print prepared port))
                   (display "\n")
                   (display (mobius-post-process (get-output-string port)))))
               ordered)
              (display "\n)\n"))))))))


  ;; Display doc + definition for a combiner using a specific mapping
  (define show-combiner-with-mapping
    (lambda (root name-index function-hash map-data)
      (let* ((mapping (cdr (assq 'mapping map-data)))
             (doc (cdr (assq 'doc map-data)))
             (name-entry (assv 0 mapping))
             (self-name (if name-entry (cdr name-entry) "?"))
             (hash->name (make-hash->name name-index root))
             (body (store-load-combiner root function-hash))
             (surface (denormalize-tree body mapping hash->name))
             (prepared (prepare-for-pretty
                        (list 'define (string->symbol self-name) surface)))
             (port (open-output-string)))
        (when (and (string? doc) (> (string-length doc) 0))
          (display (doc->comment-string doc))
          (display "\n"))
        (parameterize ((pretty-line-length 72))
          (pretty-print prepared port))
        (display (mobius-post-process (get-output-string port))))))

  (define command-show
    (lambda (arguments)
      (when (null? arguments)
        (display "bb show: missing ref\n" (current-error-port))
        (exit 1))
      (let* ((root (store-find-root (current-directory)))
             (name-index (store-build-name-index root)))
        (let-values (((function-hash lang mapping-prefix)
                      (resolve-ref name-index root (car arguments))))
          (let ((map-data (resolve-ref-mapping root function-hash lang mapping-prefix)))
            (show-combiner-with-mapping root name-index function-hash map-data))))))

  (define command-tree
    (lambda (arguments)
      (when (null? arguments)
        (display "bb tree: missing name or hash\n" (current-error-port))
        (exit 1))
      (let* ((name (car arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (hash (let-values (((h l m) (resolve-ref name-index root name))) h))
             (hash->name (make-hash->name name-index root))
             (short-hash (store-make-short-hash (store-list-all-stored-hashes root))))
        (define visited (make-hashtable string-hash string=?))
        (define print-tree
          (lambda (fhash depth)
            (unless (hashtable-ref visited fhash #f)
              (hashtable-set! visited fhash #t)
              (let* ((display-name (or (hash->name fhash)
                                       (short-hash fhash)))
                     (body (store-load-combiner root fhash))
                     (deps (extract-refs body))
                     ;; Deduplicate
                     (seen (make-hashtable string-hash string=?))
                     (unique-deps
                      (filter (lambda (h)
                                (if (hashtable-ref seen h #f)
                                    #f
                                    (begin (hashtable-set! seen h #t) #t)))
                              deps)))
                (display (make-string (* depth 2) #\space))
                (display display-name)
                (display " [")
                (display (short-hash fhash))
                (display "]\n")
                (for-each
                 (lambda (dep-hash)
                   (print-tree dep-hash (+ depth 1)))
                 unique-deps)))))
        (print-tree hash 0))))

  ;; ================================================================
  ;; bb check — run checks for ref and its dependencies
  ;; ================================================================

  (define command-check
    (lambda (arguments)
      (when (null? arguments)
        (display "bb check: missing ref\n" (current-error-port))
        (exit 1))
      (let* ((root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (hash (let-values (((h l m) (resolve-ref name-index root (car arguments)))) h))
             (hash->name (make-hash->name name-index root)))

        ;; Walk dependency graph (reuses command-tree pattern)
        (let ((visited (make-hashtable string-hash string=?)))
          (let walk! ((fhash hash))
            (unless (hashtable-ref visited fhash #f)
              (hashtable-set! visited fhash #t)
              (guard (exn (#t (void)))
                (let ((deps (extract-refs (store-load-combiner root fhash))))
                  (for-each walk! deps)))))

          ;; Collect check hashes per combiner
          (let* ((all-hashes (hashtable-keys visited))
                 (check-plan
                  (let loop ((i 0) (acc '()))
                    (if (= i (vector-length all-hashes)) acc
                        (let* ((h (vector-ref all-hashes i))
                               (checks (store-load-checks root h)))
                          (loop (+ i 1)
                                (if (null? checks) acc
                                    (cons (cons h checks) acc)))))))
                 ;; Build environment (same as command-run)
                 (environment (install-base-library (make-initial-environment)))
                 (environment (load-index-into-env name-index root environment)))

            ;; Run checks, report results
            (let ((total 0) (passed 0) (failed 0))
              (for-each
               (lambda (entry)
                 (let ((combiner-name (or (hash->name (car entry))
                                          (substring (car entry) 0 12))))
                   (for-each
                    (lambda (check-hash)
                      (set! total (+ total 1))
                      (let ((check-name (or (hash->name check-hash)
                                            (substring check-hash 0 12))))
                        (guard (exn
                                (#t (set! failed (+ failed 1))
                                    (display "FAIL  ")
                                    (display combiner-name)
                                    (display " / ")
                                    (display check-name)
                                    (display " — ")
                                    (display (if (message-condition? exn)
                                                 (condition-message exn)
                                                 "error"))
                                    (newline)))
                          (let* ((check-fn (load-combiner-value root check-hash hash->name environment))
                                 (combiner-val (load-combiner-value root (car entry) hash->name environment))
                                 (result (mobius-apply check-fn (cons combiner-val mobius-nil) environment)))
                            (if (mobius-user-combiner? result)
                                ;; Z3 symbolic check
                                (if (z3-available?)
                                    (let ((z3-result (z3-verify-property result combiner-val environment)))
                                      (case (car z3-result)
                                        ((pass)
                                         (set! passed (+ passed 1))
                                         (display "Z3-PASS  ")
                                         (display combiner-name)
                                         (display " / ")
                                         (display check-name)
                                         (newline))
                                        ((fail)
                                         (set! failed (+ failed 1))
                                         (display "Z3-FAIL  ")
                                         (display combiner-name)
                                         (display " / ")
                                         (display check-name)
                                         (display " — ")
                                         (display (cdr z3-result))
                                         (newline))
                                        (else
                                         (set! failed (+ failed 1))
                                         (display "Z3-ERR   ")
                                         (display combiner-name)
                                         (display " / ")
                                         (display check-name)
                                         (display " — ")
                                         (display (cdr z3-result))
                                         (newline))))
                                    (begin
                                      (set! passed (+ passed 1))
                                      (display "Z3-SKIP  ")
                                      (display combiner-name)
                                      (display " / ")
                                      (display check-name)
                                      (display " — z3 not in PATH")
                                      (newline)))
                                ;; Traditional runtime check passed
                                (begin
                                  (set! passed (+ passed 1))
                                  (display "PASS  ")
                                  (display combiner-name)
                                  (display " / ")
                                  (display check-name)
                                  (newline)))))))
                    (cdr entry))))
               check-plan)
              (newline)
              (display total) (display " check(s), ")
              (display passed) (display " passed, ")
              (display failed) (display " failed.\n")
              (unless (= failed 0) (exit 1))))))))

  ;; ================================================================
  ;; bb caller — show reverse dependency DAG
  ;; ================================================================

  (define command-caller
    (lambda (arguments)
      (when (null? arguments)
        (display "bb caller: missing name or hash\n" (current-error-port))
        (exit 1))
      (let* ((name (car arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (target-hash (let-values (((h l m) (resolve-ref name-index root name))) h))
             (hash->name (make-hash->name name-index root))
             (short-hash (store-make-short-hash (store-list-all-stored-hashes root))))
        (display "Callers of ")
        (display (or (hash->name target-hash) target-hash))
        (display ":\n")
        (for-each
         (lambda (entry)
           (let* ((entry-name (car entry))
                  (entry-hash (cdr entry))
                  (body (store-load-combiner root entry-hash))
                  (deps (extract-refs body)))
             (when (member target-hash deps)
               (display "  ")
               (display entry-name)
               (display " [")
               (display (short-hash entry-hash))
               (display "]\n"))))
         name-index))))

  ;; ================================================================
  ;; bb log — show lineage timeline
  ;; ================================================================

  ;; List all lineage files for a combiner (both wip and committed)
  (define list-lineage-files
    (lambda (root function-hash)
      (let ((lineage-dir (store-path-join (store-combiner-directory root function-hash)
                                     "lineage")))
        (if (file-exists? lineage-dir)
            (filter (lambda (f) (store-string-suffix? ".scm" f))
                    (directory-list lineage-dir))
            '()))))

  ;; Load a lineage record
  (define load-lineage-record
    (lambda (root function-hash filename)
      (let ((path (store-path-join (store-combiner-directory root function-hash)
                              "lineage" filename)))
        (call-with-input-file path read))))

  (define command-log
    (lambda (arguments)
      (let* ((root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (hash->name (make-hash->name name-index root))
             (short-hash (store-make-short-hash (store-list-all-stored-hashes root)))
             ;; Collect all lineage records
             (records
              (if (null? arguments)
                  ;; All combiners
                  (apply append
                    (map (lambda (entry)
                           (let ((fhash (cdr entry)))
                             (map (lambda (file)
                                    (cons fhash
                                          (load-lineage-record root fhash file)))
                                  (list-lineage-files root fhash))))
                         name-index))
                  ;; Specific combiner
                  (let* ((name (car arguments))
                         (fhash (let-values (((h l m) (resolve-ref name-index root name))) h)))
                    (map (lambda (file)
                           (cons fhash
                                 (load-lineage-record root fhash file)))
                         (list-lineage-files root fhash)))))
             ;; Sort by timestamp (committed or created)
             (sorted (sort (lambda (a b)
                             (let ((ta (or (let ((c (assq 'committed (cdr a))))
                                             (and c (cdr c)))
                                           (let ((c (assq 'created (cdr a))))
                                             (and c (cdr c)))))
                                   (tb (or (let ((c (assq 'committed (cdr b))))
                                             (and c (cdr c)))
                                           (let ((c (assq 'created (cdr b))))
                                             (and c (cdr c))))))
                               (if (and ta tb) (string<? ta tb) #f)))
                           records)))
        (if (null? sorted)
            (display "No lineage records found.\n")
            (for-each
             (lambda (record)
               (let* ((fhash (car record))
                      (data (cdr record))
                      (name (hash->name fhash))
                      (timestamp (or (let ((c (assq 'committed data)))
                                       (and c (cdr c)))
                                     (let ((c (assq 'created data)))
                                       (and c (cdr c)))))
                      (author (let ((a (assq 'author data)))
                                (and a (cdr a))))
                      (relation (let ((r (assq 'relation data)))
                                  (and r (cdr r))))
                      (is-wip? (not (assq 'committed data))))
                 (when timestamp (display timestamp))
                 (display "  ")
                 (display (or relation "?"))
                 (when is-wip? (display " [wip]"))
                 (display "  ")
                 (if name
                     (begin (display name) (display "  "))
                     (void))
                 (display (short-hash fhash))
                 (when (and (string? author) (not (string=? author "")))
                   (display "  by ")
                   (display author))
                 (newline)))
             sorted)))))

  ;; ================================================================
  ;; bb run — evaluate a registered combiner
  ;; ================================================================

  (define command-run
    (lambda (arguments)
      (when (null? arguments)
        (display "bb run: missing ref\n" (current-error-port))
        (exit 1))
      (let* ((debug? (and (not (null? arguments))
                          (string=? (car arguments) "--debug")))
             (arguments (if debug? (cdr arguments) arguments)))
        (when (null? arguments)
          (display "bb run: missing ref\n" (current-error-port))
          (exit 1))
      (let* ((name (car arguments))
             (rest-arguments (cdr arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (all-hashes (store-list-all-stored-hashes root))
             (short-hash (store-make-short-hash all-hashes))
             (hash (let-values (((h l m) (resolve-ref name-index root name))) h))
             (hash->name (make-hash->name name-index root))
             (resolved-name (hash->name hash)))
        (when debug?
          (display "resolve: " (current-error-port))
          (display name (current-error-port))
          (display " -> " (current-error-port))
          (when resolved-name
            (display resolved-name (current-error-port))
            (display " " (current-error-port)))
          (display "[" (current-error-port))
          (display (short-hash hash) (current-error-port))
          (display "]" (current-error-port))
          (newline (current-error-port)))
        (let* ((environment (install-base-library (make-initial-environment)))
               (environment (load-index-into-env name-index root environment))
               (combiner-name (or resolved-name (string->symbol name)))
               (combiner (name-environment-ref environment combiner-name)))
          (if (null? rest-arguments)
              (let ((result (mobius-apply combiner mobius-nil environment)))
                (unless (mobius-void? result)
                  (mobius-display-value result)
                  (newline)))
              (let* ((argument-tree (build-argument-tree rest-arguments))
                     (result (mobius-apply combiner argument-tree environment)))
                (mobius-display-value result)
                (newline))))))))

  ;; ================================================================
  ;; Edit helpers — doc extraction, classify, check running, storage
  ;; ================================================================

  ;; Extract leading ;; comment lines from source text as a doc string.
  (define source-extract-doc
    (lambda (source)
      (let ((port (open-input-string source)))
        (let loop ((doc-lines '()))
          (let ((line (get-line port)))
            (cond
             ((eof-object? line)
              (doc-lines->string (reverse doc-lines)))
             ((and (>= (string-length line) 2)
                   (char=? (string-ref line 0) #\;)
                   (char=? (string-ref line 1) #\;))
              (loop (cons (if (and (> (string-length line) 3)
                                   (char=? (string-ref line 2) #\space))
                              (substring line 3 (string-length line))
                              (substring line 2 (string-length line)))
                          doc-lines)))
             ;; Skip blank lines between doc comments
             ((string=? (string-trim-whitespace line) "")
              (if (null? doc-lines)
                  (loop doc-lines)
                  (doc-lines->string (reverse doc-lines))))
             (else
              (doc-lines->string (reverse doc-lines)))))))))

  (define doc-lines->string
    (lambda (lines)
      (if (null? lines)
          ""
          (let loop ((remaining (cdr lines)) (result (car lines)))
            (if (null? remaining)
                result
                (loop (cdr remaining)
                      (string-append result "\n" (car remaining))))))))

  ;; Convert a doc string (possibly multi-line) into ;; prefixed comment block.
  (define doc->comment-string
    (lambda (doc)
      (let ((lines (string-split-lines doc)))
        (let loop ((remaining lines) (result ""))
          (if (null? remaining)
              result
              (loop (cdr remaining)
                    (string-append result
                                   (if (string=? result "") "" "\n")
                                   ";; " (car remaining))))))))

  (define string-trim-whitespace
    (lambda (string)
      (let ((length (string-length string)))
        (let ((start (let loop ((i 0))
                       (if (and (< i length)
                                (char-whitespace? (string-ref string i)))
                           (loop (+ i 1))
                           i)))
              (end (let loop ((i length))
                     (if (and (> i 0)
                              (char-whitespace? (string-ref string (- i 1))))
                         (loop (- i 1))
                         i))))
          (if (>= start end)
              ""
              (substring string start end))))))

  ;; Classify parsed defines into main and check defines.
  ;; Returns (values main-defines check-defines).
  (define classify-defines
    (lambda (expressions)
      (let loop ((remaining expressions) (mains '()) (checks '()))
        (if (null? remaining)
            (values (reverse mains) (reverse checks))
            (let ((expression (car remaining)))
              (if (and (pair? expression) (eq? 'define (car expression)))
                  (let ((name (symbol->string (cadr expression))))
                    (if (and (> (string-length name) 0)
                             (char=? (string-ref name 0) #\~))
                        (loop (cdr remaining) mains (cons expression checks))
                        (loop (cdr remaining) (cons expression mains) checks)))
                  (loop (cdr remaining) mains checks)))))))

  ;; Run each ~check-* combiner from the evaluated environment.
  ;; Each check receives its corresponding main combiner as argument.
  ;; Match by name convention (~check-foo -> foo, ~check-foo-00 -> foo),
  ;; falling back to the sole main define when there's exactly one.
  ;; Returns list of (name . #t) or (name . error-string).
  (define edit-run-checks
    (lambda (check-defines main-defines final-environment)
      (let* ((main-names (map cadr main-defines))
             (sole-main-val
              (and (= (length main-defines) 1)
                   (guard (exn (#t #f))
                     (name-environment-ref final-environment
                                           (car main-names))))))
        (map (lambda (expression)
               (let* ((name (cadr expression))
                      (name-str (symbol->string name))
                      ;; Strip ~check- prefix, then remove trailing -NN suffix
                      (base-str (if (and (> (string-length name-str) 7)
                                         (string=? (substring name-str 0 7) "~check-"))
                                    (substring name-str 7 (string-length name-str))
                                    name-str))
                      (main-name-str
                       (let ((len (string-length base-str)))
                         (if (and (>= len 3)
                                  (char=? (string-ref base-str (- len 3)) #\-)
                                  (char-numeric? (string-ref base-str (- len 2)))
                                  (char-numeric? (string-ref base-str (- len 1))))
                             (substring base-str 0 (- len 3))
                             base-str)))
                      (main-name (string->symbol main-name-str))
                      (main-val (if (memq main-name main-names)
                                    (guard (exn (#t sole-main-val))
                                      (name-environment-ref final-environment main-name))
                                    sole-main-val)))
                 (guard (exn (#t (cons name
                                       (if (message-condition? exn)
                                           (condition-message exn)
                                           "unknown error"))))
                   (let* ((check-fn (name-environment-ref final-environment name))
                          (result (if main-val
                                      (mobius-apply check-fn (cons main-val mobius-nil) final-environment)
                                      (mobius-apply check-fn mobius-nil final-environment))))
                     (if (mobius-user-combiner? result)
                         ;; Z3 symbolic check
                         (if (and main-val (z3-available?))
                             (let ((z3-result (z3-verify-property result main-val final-environment)))
                               (case (car z3-result)
                                 ((pass) (cons name #t))
                                 ((fail) (cons name (string-append "Z3: " (cdr z3-result))))
                                 (else (cons name (string-append "Z3: " (cdr z3-result))))))
                             (cons name #t))  ;; skip if no z3 or no main-val
                         ;; Traditional check passed
                         (cons name #t))))))
             check-defines))))

  ;; Store all defines (main + checks) into the content-addressed store.
  ;; Main defines are stored first (checks may reference them).
  ;; Check defines are stored next, then main tree.scm is updated with check hashes.
  (define edit-store-all!
    (lambda (root name-index lang doc main-defines check-defines
                  name-lookup author derived-from-hash relation)
      (let ((main-hashes '()))
        ;; Store each main combiner first (without checks initially)
        (for-each
         (lambda (expression)
           (let* ((defined-name (cadr expression))
                  (value-expression (caddr expression)))
             (let-values (((normalized-tree mapping)
                           (normalize-combiner value-expression
                                               defined-name
                                               name-lookup)))
               (let* ((serialized (scheme-write-value normalized-tree))
                      (function-hash (sha256-string serialized))
                      ;; If this combiner already exists, the user is adding a
                      ;; new mapping for the same body — record it as a
                      ;; translation, not a fresh add. Explicit relation choices
                      ;; (fork, refine, etc.) override.
                      (pre-existing? (file-exists?
                                      (store-combiner-tree-path root function-hash)))
                      (effective-relation
                       (if (and pre-existing? (string=? relation "add"))
                           "translate"
                           relation)))
                 ;; Shadow note: warn when this name already resolves to a different hash
                 (let* ((name-str (symbol->string defined-name))
                        (existing-entry (assoc name-str name-index)))
                   (when (and existing-entry
                              (not (string=? (cdr existing-entry) function-hash)))
                     (display (string-append "  note: '" name-str "' shadows "
                                             (substring (cdr existing-entry) 0
                                                        (min 12 (string-length (cdr existing-entry))))
                                             "\n"))))
                 (store-combiner! root function-hash normalized-tree)
                 (store-mapping! root function-hash lang mapping doc)
                 (store-record-wip-lineage! root function-hash author effective-relation
                                      derived-from-hash)
                 (set! name-index
                   (cons (cons (symbol->string defined-name) function-hash)
                         (filter (lambda (e)
                                   (not (string=? (car e)
                                                  (symbol->string defined-name))))
                                 name-index)))
                 (set! main-hashes (cons (list function-hash normalized-tree effective-relation)
                                         main-hashes))
                 (display "  staged: ")
                 (display defined-name)
                 (display " -> ")
                 (display function-hash)
                 (display "\n")))))
         main-defines)
        ;; Now store check combiners (name-index has mains)
        (let ((check-hashes '())
              (name-lookup (make-name-lookup name-index root)))
          (for-each
           (lambda (expression)
             (let* ((defined-name (cadr expression))
                    (value-expression (caddr expression))
                    (check-self-name defined-name))
               (let-values (((normalized-tree mapping)
                             (normalize-combiner value-expression
                                                 check-self-name
                                                 name-lookup)))
                 (let* ((serialized (scheme-write-value normalized-tree))
                        (function-hash (sha256-string serialized)))
                   (store-combiner! root function-hash normalized-tree)
                   (store-mapping! root function-hash lang mapping "")
                   (store-record-wip-lineage! root function-hash author "add")
                   (set! check-hashes (cons function-hash check-hashes))
                   (set! name-index
                     (cons (cons (symbol->string defined-name) function-hash)
                           (filter (lambda (e)
                                     (not (string=? (car e)
                                                    (symbol->string defined-name))))
                                   name-index)))
                   (display "  staged: ")
                   (display defined-name)
                   (display " -> ")
                   (display function-hash)
                   (display "\n")))))
           check-defines)
          ;; Record checks in main combiner lineage
          (unless (null? check-hashes)
            (for-each
             (lambda (main-pair)
               (let ((function-hash (car main-pair))
                     (effective-relation (caddr main-pair)))
                 (store-record-wip-lineage! root function-hash author effective-relation
                                      derived-from-hash #f
                                      (reverse check-hashes))))
             main-hashes))
          ;; Diff buffer checks vs store checks for unchanged combiners.
          ;; When the main hash equals derived-from-hash the logic didn't change;
          ;; any check present in the store but absent from the buffer is a retraction.
          (when derived-from-hash
            (let* ((buffer-hashes (reverse check-hashes))
                   (store-checks (store-load-checks root derived-from-hash))
                   (to-retract (filter (lambda (h) (not (member h buffer-hashes)))
                                       store-checks)))
              (unless (null? to-retract)
                (for-each
                 (lambda (main-pair)
                   (when (equal? (car main-pair) derived-from-hash)
                     (store-record-wip-retract-checks! root derived-from-hash author
                                                       to-retract)))
                 main-hashes)))))
        name-index)))

  ;; Read one line from the controlling TTY. bb's stdin is usually a pipe
  ;; from the launcher script (echo ... | scheme), so (current-input-port)
  ;; is at EOF by the time we prompt interactively.
  (define edit-read-tty-line
    (lambda ()
      (guard (exn (#t #f))
        (let* ((port (open-file-input-port "/dev/tty"
                                           (file-options)
                                           (buffer-mode line)
                                           (native-transcoder)))
               (line (get-line port)))
          (close-port port)
          (if (eof-object? line) #f line)))))

  ;; After a successful edit, ask the user to flag the change.
  ;; Returns "refine" or "fork". Defaults to "refine" when input is unclear.
  (define edit-prompt-relation
    (lambda ()
      (flush-output-port (current-output-port))
      (display "\nFlag change as (r)efine or (f)ork? [r] ")
      (flush-output-port (current-output-port))
      (let ((response (edit-read-tty-line)))
        (cond
         ((and (string? response)
               (or (string=? response "f")
                   (string=? response "fork")))
          "fork")
         (else "refine")))))

  ;; Display an error message and prompt user for action.
  ;; Returns symbol: re-edit or exit.
  ;; source: full buffer contents at the time of failure, or #f if unavailable.
  (define edit-prompt-on-error
    (lambda (message original-hash root source)
      (display "\nError: " (current-error-port))
      (display message (current-error-port))
      (display "\n" (current-error-port))
      (display "\n(r)ewrite, (w)orklog, or (e)xit? " (current-error-port))
      (flush-output-port (current-error-port))
      (let ((response (edit-read-tty-line)))
        (cond
         ((and (string? response)
               (or (string=? response "r")
                   (string=? response "rewrite")))
          're-edit)
         ((and (string? response)
               (or (string=? response "w")
                   (string=? response "worklog")))
          (when original-hash
            (let ((worklog-message
                   (if (and (string? source) (positive? (string-length source)))
                       (string-append "Error: " message "\n\nSource:\n" source)
                       (string-append "Error: " message))))
              (store-add-worklog-entry! root original-hash worklog-message))
            (display "Worklog entry added.\n" (current-error-port)))
          'exit)
         (else 'exit)))))

  ;; Re-open the editor and recurse into edit-save-flow on success.
  (define edit-reopen
    (lambda (root name-index lang original-hash editor tmp-file derived-from-hash)
      (let ((status (system (string-append editor " " tmp-file " </dev/tty >/dev/tty"))))
        (when (= status 0)
          (let ((new-source
                 (guard (exn (#t #f))
                   (call-with-input-file tmp-file get-string-all))))
            (if new-source
                (edit-save-flow new-source root name-index lang
                                original-hash editor tmp-file derived-from-hash)
                (let ((action (edit-prompt-on-error
                               "could not read file after editor exit"
                               original-hash root #f)))
                  (when (eq? action 're-edit)
                    (edit-reopen root name-index lang original-hash
                                 editor tmp-file derived-from-hash)))))))))

  ;; Full edit-save flow: parse, eval, run checks, store or handle failure.
  ;; Returns when done (possibly after re-edit loops).
  ;; derived-from-hash: if non-#f, overrides original-hash in lineage (for --derived-from flag).
  ;; original-hash: hash of the combiner being edited, used for check retraction diff.
  (define edit-save-flow
    (lambda (source root name-index lang original-hash editor tmp-file . rest)
      (let* ((derived-from-hash (if (null? rest) original-hash (car rest)))
             (lang (or lang (guard (exn (#t "en"))
                              (car (store-config-languages root))))))
        ;; Parse
        (let ((parse-result
               (guard (exn (#t (cons 'error
                                     (if (message-condition? exn)
                                         (condition-message exn)
                                         "syntax error"))))
                 (cons 'ok (mobius-read-all-string source)))))
          (if (eq? (car parse-result) 'error)
              (let ((action (edit-prompt-on-error (cdr parse-result) original-hash root source)))
                (when (eq? action 're-edit)
                  (edit-reopen root name-index lang original-hash
                               editor tmp-file derived-from-hash)))
              (let* ((expressions (cdr parse-result))
                     (doc (source-extract-doc source))
                     (environment (install-base-library (make-initial-environment)))
                     (environment (load-index-into-env name-index root environment))
                     (author (store-config-author root))
                     (name-lookup (make-name-lookup name-index root)))
                (let-values (((main-defines check-defines) (classify-defines expressions)))
                  ;; Evaluate
                  (let ((eval-result
                         (guard (exn (#t (cons 'error
                                               (if (message-condition? exn)
                                                   (condition-message exn)
                                                   "evaluation error"))))
                           (let-values (((env val)
                                         (mobius-eval-top-level expressions environment)))
                             (cons 'ok (cons env val))))))
                    (if (eq? (car eval-result) 'error)
                        (let ((action (edit-prompt-on-error (cdr eval-result) original-hash root source)))
                          (when (eq? action 're-edit)
                            (edit-reopen root name-index lang original-hash
                                         editor tmp-file derived-from-hash)))
                        (let* ((final-environment (cadr eval-result))
                               (try-store
                                (lambda (relation)
                                  (guard (exn (#t (cons 'error
                                                        (if (message-condition? exn)
                                                            (condition-message exn)
                                                            "store error"))))
                                    (edit-store-all! root name-index lang doc main-defines
                                                     check-defines name-lookup author
                                                     derived-from-hash relation)
                                    'ok))))
                          (if (null? check-defines)
                              ;; No checks — store directly
                              (let ((store-result (try-store (edit-prompt-relation))))
                                (if (eq? store-result 'ok)
                                    (display "Done. Use 'bb commit' to finalize.\n")
                                    (let ((action (edit-prompt-on-error (cdr store-result) original-hash root source)))
                                      (when (eq? action 're-edit)
                                        (edit-reopen root name-index lang original-hash
                                                     editor tmp-file derived-from-hash)))))
                              ;; Run checks
                              (let ((results (edit-run-checks check-defines main-defines final-environment)))
                                (if (for-all (lambda (r) (eq? #t (cdr r))) results)
                                    ;; All passed
                                    (begin
                                      (for-each
                                       (lambda (r)
                                         (display "  PASS ")
                                         (display (car r))
                                         (display "\n"))
                                       results)
                                      (let ((store-result (try-store (edit-prompt-relation))))
                                        (if (eq? store-result 'ok)
                                            (display "Done. Use 'bb commit' to finalize.\n")
                                            (let ((action (edit-prompt-on-error (cdr store-result) original-hash root source)))
                                              (when (eq? action 're-edit)
                                                (edit-reopen root name-index lang original-hash
                                                             editor tmp-file derived-from-hash))))))
                                    ;; Some checks failed
                                    (let ((msg (apply string-append
                                                      (map (lambda (r)
                                                             (if (eq? #t (cdr r)) ""
                                                                 (string-append "FAIL " (symbol->string (car r))
                                                                                ": " (cdr r) "\n")))
                                                           results))))
                                      (let ((action (edit-prompt-on-error msg original-hash root source)))
                                        (when (eq? action 're-edit)
                                          (edit-reopen root name-index lang original-hash
                                                       editor tmp-file derived-from-hash)))))))))))))))))

  ;; ================================================================
  ;; bb edit — denormalize stored combiner to editable source
  ;; ================================================================

  ;; Pretty-print a single define expression to a string.
  (define define->pretty-string
    (lambda (display-name surface)
      (let* ((prepared (prepare-for-pretty
                        (list 'define (if (symbol? display-name)
                                          display-name
                                          (string->symbol
                                           (if (string? display-name)
                                               display-name
                                               (symbol->string display-name))))
                              surface)))
             (pp-port (open-output-string)))
        (parameterize ((pretty-line-length 72))
          (pretty-print prepared pp-port))
        (mobius-post-process (get-output-string pp-port)))))

  (define command-edit
    (lambda (arguments)
      (when (null? arguments)
        (display "bb edit: missing ref\n" (current-error-port))
        (exit 1))
      (let* ((derived-from-raw
              (let loop ((remaining arguments))
                (cond ((null? remaining) #f)
                      ((and (>= (string-length (car remaining)) 15)
                            (string=? (substring (car remaining) 0 15) "--derived-from="))
                       (substring (car remaining) 15 (string-length (car remaining))))
                      (else (loop (cdr remaining))))))
             (positional
              (filter (lambda (a)
                        (not (and (>= (string-length a) 15)
                                  (string=? (substring a 0 15) "--derived-from="))))
                      arguments))
             (arg-lang (if (and (>= (length positional) 2)
                                (not (and (>= (string-length (cadr positional)) 2)
                                          (char=? (string-ref (cadr positional) 0) #\-)
                                          (char=? (string-ref (cadr positional) 1) #\-))))
                           (cadr positional)
                           #f))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root)))
        (let-values (((hash ref-lang ref-mapping) (resolve-ref name-index root (car positional))))
          (let* ((lang (or arg-lang ref-lang))
                 (hash->name (make-hash->name name-index root))
                 (body (store-load-combiner root hash))
                 (check-hashes (latest-committed-lineage-checks root hash))
                 (map-data (if lang
                               (store-load-mapping-by-language root hash lang)
                               (store-load-preferred-mapping root hash)))
                 (mapping (cdr (assq 'mapping map-data)))
                 (doc-entry (assq 'doc map-data))
                 (doc (if (and doc-entry (string? (cdr doc-entry))
                               (> (string-length (cdr doc-entry)) 0))
                          (cdr doc-entry)
                          #f))
                 (surface (denormalize-tree body mapping hash->name))
                 (display-name (or (hash->name hash) (car positional)))
                 (name-str (if (symbol? display-name)
                              (symbol->string display-name)
                              display-name))
                 (derived-from-hash
                  (and derived-from-raw
                       (let-values (((h l m) (resolve-ref name-index root derived-from-raw))) h)))
                 (editor (or (getenv "EDITOR") (getenv "VISUAL") "vi"))
                 (tmp-file (string-append "/tmp/bb-edit-" name-str ".scm")))
            ;; Build full edit buffer: doc + main define + check defines
            (let ((buffer (open-output-string)))
              ;; Doc comments
              (when doc
                (for-each
                 (lambda (line)
                   (display ";; " buffer)
                   (display line buffer)
                   (display "\n" buffer))
                 (string-split-lines doc))
                (display "\n" buffer))
              ;; Main define
              (display (define->pretty-string display-name surface) buffer)
              ;; Check defines
              (for-each
               (lambda (check-hash)
                 (guard (exn (#t (void)))
                   (let* ((ck-body (store-load-combiner root check-hash))
                          (ck-map-data (if lang
                                           (guard (exn (#t (store-load-preferred-mapping root check-hash)))
                                             (store-load-mapping-by-language root check-hash lang))
                                           (store-load-preferred-mapping root check-hash)))
                          (ck-mapping (cdr (assq 'mapping ck-map-data)))
                          (ck-surface (denormalize-tree ck-body ck-mapping hash->name))
                          (ck-name-entry (assv 0 ck-mapping))
                          (ck-name (if ck-name-entry
                                       (let ((n (cdr ck-name-entry)))
                                         ;; Use name as-is if it already has ~check- prefix
                                         (string->symbol
                                          (if (and (> (string-length n) 7)
                                                   (string=? (substring n 0 7) "~check-"))
                                              n
                                              (string-append "~check-" n))))
                                       (string->symbol (string-append "~check-" name-str)))))
                     (display "\n" buffer)
                     (display (define->pretty-string ck-name ck-surface) buffer))))
               check-hashes)
              ;; Write buffer to temp file
              (call-with-output-file tmp-file
                (lambda (port)
                  (display (get-output-string buffer) port))
                'replace))
            ;; Open editor and run save flow
            (let ((status (system (string-append editor " " tmp-file " </dev/tty >/dev/tty"))))
              (when (= status 0)
                (let ((source
                       (guard (exn (#t #f))
                         (call-with-input-file tmp-file get-string-all))))
                  (if source
                      (edit-save-flow source root name-index lang hash
                                      editor tmp-file derived-from-hash)
                      (let ((action (edit-prompt-on-error
                                     "could not read file after editor exit"
                                     hash root #f)))
                        (when (eq? action 're-edit)
                          (edit-reopen root name-index lang hash
                                       editor tmp-file derived-from-hash))))))))))))

  ;; ================================================================
  ;; bb commit — promote wip lineage to committed
  ;; ================================================================

  (define command-commit
    (lambda (arguments)
      (let* ((root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (author (store-config-author root))
             (names (if (and (not (null? arguments))
                             (string=? (car arguments) "--all"))
                        (map car name-index)
                        arguments)))
        (when (null? names)
          (display "bb commit: specify names or --all\n" (current-error-port))
          (exit 1))
        (let ((count 0))
          (for-each
           (lambda (name)
             (let ((entry (assoc name name-index)))
               (if entry
                   (let* ((fhash (cdr entry))
                          ;; All wip records sorted ascending by 'created.
                          ;; Each distinct created timestamp is one user event;
                          ;; within a single event edit-store-all! may write a
                          ;; no-checks intermediate followed by a with-checks
                          ;; final. We keep the with-checks variant when both
                          ;; appear at the same timestamp.
                          (wip-files (store-list-wip-files root fhash))
                          (wip-records-asc
                           (sort (lambda (a b)
                                   (let ((ta (cdr (assq 'created a)))
                                         (tb (cdr (assq 'created b))))
                                     (cond
                                      ((string<? ta tb) #t)
                                      ((string<? tb ta) #f)
                                      (else
                                       ;; with-checks before no-checks within tie,
                                       ;; so the later "wins" filter prefers it.
                                       (and (assq 'checks a)
                                            (not (assq 'checks b)))))))
                                 (map (lambda (f) (load-lineage-record root fhash f))
                                      wip-files)))
                          (retract-records
                           (filter (lambda (r)
                                     (let ((rel (assq 'relation r)))
                                       (and rel (string=? (cdr rel) "retract-checks"))))
                                   wip-records-asc))
                          (add-records
                           (filter (lambda (r)
                                     (let ((rel (assq 'relation r)))
                                       (or (not rel)
                                           (not (string=? (cdr rel) "retract-checks")))))
                                   wip-records-asc))
                          ;; One representative per distinct 'created timestamp.
                          ;; The last add seen at a given ts wins, which—given
                          ;; the sort tie-break above—is the with-checks one.
                          (add-representatives
                           (let loop ((remaining add-records)
                                      (last-ts #f)
                                      (acc '()))
                             (cond
                              ((null? remaining) (reverse acc))
                              (else
                               (let* ((r (car remaining))
                                      (ts (cdr (assq 'created r))))
                                 (cond
                                  ((and last-ts (string=? ts last-ts))
                                   ;; Replace previous representative for this ts.
                                   (loop (cdr remaining) ts (cons r (cdr acc))))
                                  (else
                                   (loop (cdr remaining) ts (cons r acc))))))))))
                     ;; Promote each add event as its own committed lineage record.
                     ;; A translate record with no 'checks field inherits the
                     ;; checks list from the most recent prior committed record
                     ;; on this combiner that carries one — translating a
                     ;; mapping shouldn't silently drop checks.
                     (for-each
                      (lambda (rep)
                        (let* ((wip-derived (let ((d (assq 'derived-from rep)))
                                              (and d (cdr d))))
                               (wip-relation (let ((r (assq 'relation rep)))
                                               (and r (cdr r))))
                               (rep-checks-cell (assq 'checks rep))
                               (wip-checks
                                (cond
                                 (rep-checks-cell (cdr rep-checks-cell))
                                 ((and wip-relation (string=? wip-relation "translate"))
                                  (latest-committed-lineage-checks root fhash))
                                 (else #f)))
                               (predecessor-lineage
                                (and wip-derived
                                     (latest-committed-lineage-hash root wip-derived))))
                          (store-record-lineage! root fhash author
                                           (or wip-relation "commit")
                                           wip-derived
                                           #f
                                           #f
                                           (if (and (pair? wip-checks)
                                                    (not (null? wip-checks)))
                                               wip-checks
                                               #f)
                                           predecessor-lineage)))
                      add-representatives)
                     ;; Carry retractions through as separate committed records.
                     (for-each
                      (lambda (r)
                        (let ((retracted (assq 'retract-checks r)))
                          (when retracted
                            (store-record-retract-checks!
                             root fhash author (cdr retracted)))))
                      retract-records)
                     (let ((latest-relation
                            (cond
                             ((null? add-representatives) "commit")
                             (else
                              (let ((r (assq 'relation (car (reverse add-representatives)))))
                                (if r (cdr r) "commit"))))))
                       (store-add-worklog-entry!
                        root fhash
                        (string-append "committed " name " ("
                                       latest-relation ")")))
                     (set! count (+ count 1))
                     (display "  committed: ")
                     (display name)
                     (newline))
                   (begin
                     (display "  unknown: ")
                     (display name)
                     (newline)))))
           names)
          (display count)
          (display " combiner(s) committed.\n")))))

  ;; ================================================================
  ;; ANSI terminal colors
  ;; ================================================================

  (define ansi-red "\x1b;[31m")
  (define ansi-green "\x1b;[32m")
  (define ansi-cyan "\x1b;[36m")
  (define ansi-reset "\x1b;[0m")

  ;; ================================================================
  ;; String utilities for diff
  ;; ================================================================

  ;; Replace all occurrences of old with new in str
  (define string-replace
    (lambda (string old new)
      (let ((old-len (string-length old))
            (string-len (string-length string)))
        (if (= old-len 0)
            string
            (let ((port (open-output-string)))
              (let loop ((i 0))
                (cond
                 ((> (+ i old-len) string-len)
                  ;; Not enough chars left for a match — flush remainder
                  (display (substring string i string-len) port)
                  (get-output-string port))
                 ((string=? (substring string i (+ i old-len)) old)
                  (display new port)
                  (loop (+ i old-len)))
                 (else
                  (display (string-ref string i) port)
                  (loop (+ i 1))))))))))

  ;; Split string on newlines, returning a list of strings.
  ;; Trailing empty string from final newline is dropped.
  (define string-split-lines
    (lambda (string)
      (let ((length (string-length string)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond
           ((= i length)
            (reverse (if (= start length)
                         acc
                         (cons (substring string start length) acc))))
           ((char=? (string-ref string i) #\newline)
            (loop (+ i 1) (+ i 1)
                  (cons (substring string start i) acc)))
           (else
            (loop (+ i 1) start acc)))))))

  ;; ================================================================
  ;; Pretty-print pre-processing
  ;; ================================================================

  ;; Walk denormalized tree, replacing Möbius values with placeholder
  ;; symbols that Chez pretty-print will render cleanly.
  ;; Value/car position: '() becomes %nil (it's #nil in Möbius).
  (define prepare-for-pretty
    (lambda (expression)
      (cond
       ((null? expression) '%nil)
       ((eq? expression #t) '%true)
       ((eq? expression #f) '%false)
       ((mobius-void? expression) '%void)
       ((mobius-eof? expression) '%eof)
       ((pair? expression)
        (if (and (eq? 'lambda (car expression))
                 (pair? (cdr expression))
                 (null? (cadr expression)))
            ;; Lambda with empty params: preserve () as syntax
            (cons 'lambda
                  (cons '()
                        (prepare-for-pretty-tail (cddr expression))))
            (cons (prepare-for-pretty (car expression))
                  (prepare-for-pretty-tail (cdr expression)))))
       (else expression))))

  ;; Tail/cdr position: '() stays as list terminator.
  (define prepare-for-pretty-tail
    (lambda (expression)
      (cond
       ((null? expression) '())
       ((pair? expression)
        (cons (prepare-for-pretty (car expression))
              (prepare-for-pretty-tail (cdr expression))))
       (else (prepare-for-pretty expression)))))

  ;; ================================================================
  ;; Pretty-print post-processing
  ;; ================================================================

  ;; Replace placeholder symbols and internal forms with Möbius syntax.
  (define mobius-post-process
    (lambda (string)
      (let* ((string (string-replace string "%true" "#true"))
             (string (string-replace string "%false" "#false"))
             (string (string-replace string "%nil" "#nil"))
             (string (string-replace string "%void" "#void"))
             (string (string-replace string "%eof" "#eof"))
             (string (string-replace string "(mobius-wildcard)" ",_")))
        ;; Handle (mobius-unquote NAME) and (mobius-unquote-recurse NAME)
        ;; by scanning for these patterns in the text.
        (let ((string (post-process-unquotes string)))
          string))))

  ;; Scan for (mobius-unquote X) → ,X and (mobius-unquote-recurse X) → ,(X)
  (define post-process-unquotes
    (lambda (string)
      (let ((uq "(mobius-unquote ")
            (uqr "(mobius-unquote-recurse "))
        (let ((string (replace-form string uqr
                     (lambda (name) (string-append ",(" name ")")))))
          (replace-form string uq
            (lambda (name) (string-append "," name)))))))

  ;; Replace (PREFIX NAME) with (transform NAME) throughout str.
  ;; PREFIX includes the trailing space, e.g. "(mobius-unquote ".
  (define replace-form
    (lambda (string prefix transform)
      (let ((prefix-len (string-length prefix))
            (string-len (string-length string)))
        (let ((port (open-output-string)))
          (let loop ((i 0))
            (cond
             ((>= i string-len)
              (get-output-string port))
             ((and (<= (+ i prefix-len) string-len)
                   (string=? (substring string i (+ i prefix-len)) prefix))
              ;; Found prefix — extract name up to closing paren
              (let name-loop ((j (+ i prefix-len)) (chars '()))
                (cond
                 ((>= j string-len)
                  ;; Malformed — just output as-is
                  (display (substring string i string-len) port)
                  (get-output-string port))
                 ((char=? (string-ref string j) #\))
                  (let ((name (list->string (reverse chars))))
                    (display (transform name) port)
                    (loop (+ j 1))))
                 (else
                  (name-loop (+ j 1) (cons (string-ref string j) chars))))))
             (else
              (display (string-ref string i) port)
              (loop (+ i 1)))))))))

  ;; ================================================================
  ;; Pretty-print pipeline
  ;; ================================================================

  ;; Pretty-print a single combiner body with its mapping, returning a string.
  (define pretty-print-one-combiner
    (lambda (root hash->name body mapping name)
      (let* ((surface (denormalize-tree body mapping hash->name))
             (prepared (prepare-for-pretty
                        (list 'define (string->symbol name) surface)))
             (port (open-output-string)))
        (parameterize ((pretty-line-length 72))
          (pretty-print prepared port))
        (mobius-post-process (get-output-string port)))))

  ;; Denormalize a combiner and return pretty-printed Möbius source as string.
  ;; Includes doc as ;; comments and check combiners appended after the main define.
  (define mobius-pretty-string
    (lambda (root name-index hash name)
      (let* ((hash->name (make-hash->name name-index root))
             (body (store-load-combiner root hash))
             (checks (store-load-checks root hash))
             (map-data (store-load-first-mapping root hash))
             (mapping (cdr (assq 'mapping map-data)))
             (doc (let ((d (assq 'doc map-data))) (if d (cdr d) "")))
             (code (pretty-print-one-combiner root hash->name body mapping name))
             ;; Pretty-print each check combiner
             (check-texts
              (map (lambda (check-hash)
                     (let* ((check-body (store-load-combiner root check-hash))
                            (check-map (store-load-first-mapping root check-hash))
                            (check-mapping (cdr (assq 'mapping check-map)))
                            (check-name-entry (assv 0 check-mapping))
                            (check-name (if check-name-entry
                                            (let ((n (cdr check-name-entry)))
                                              (if (and (> (string-length n) 7)
                                                       (string=? (substring n 0 7) "~check-"))
                                                  n
                                                  (string-append "~check-" n)))
                                            (string-append "~check-" name))))
                       (pretty-print-one-combiner
                        root hash->name check-body check-mapping check-name)))
                   checks)))
        (let ((result (if (and (string? doc) (> (string-length doc) 0))
                          (string-append (doc->comment-string doc) "\n" code)
                          code)))
          (if (null? check-texts)
              result
              (apply string-append result "\n"
                     (let loop ((remaining check-texts) (acc '()))
                       (if (null? remaining)
                           (reverse acc)
                           (loop (cdr remaining)
                                 (cons (if (null? (cdr remaining))
                                           (car remaining)
                                           (string-append (car remaining) "\n"))
                                       acc))))))))))

  ;; ================================================================
  ;; LCS-based line diff
  ;; ================================================================

  ;; Compute LCS of two lists of strings. Returns list of common lines.
  (define lcs-lines
    (lambda (lines1 lines2)
      (let* ((v1 (list->vector lines1))
             (v2 (list->vector lines2))
             (m (vector-length v1))
             (n (vector-length v2))
             ;; DP table: (m+1) x (n+1) vector of vectors
             (table (let ((t (make-vector (+ m 1))))
                      (let loop ((i 0))
                        (when (<= i m)
                          (vector-set! t i (make-vector (+ n 1) 0))
                          (loop (+ i 1))))
                      t)))
        ;; Fill table
        (let loop-i ((i 1))
          (when (<= i m)
            (let loop-j ((j 1))
              (when (<= j n)
                (if (string=? (vector-ref v1 (- i 1))
                              (vector-ref v2 (- j 1)))
                    (vector-set! (vector-ref table i) j
                                 (+ 1 (vector-ref (vector-ref table (- i 1))
                                                   (- j 1))))
                    (vector-set! (vector-ref table i) j
                                 (max (vector-ref (vector-ref table (- i 1)) j)
                                      (vector-ref (vector-ref table i) (- j 1)))))
                (loop-j (+ j 1))))
            (loop-i (+ i 1))))
        ;; Backtrack to extract LCS
        (let backtrack ((i m) (j n) (acc '()))
          (cond
           ((or (= i 0) (= j 0)) acc)
           ((string=? (vector-ref v1 (- i 1))
                      (vector-ref v2 (- j 1)))
            (backtrack (- i 1) (- j 1)
                       (cons (vector-ref v1 (- i 1)) acc)))
           ((> (vector-ref (vector-ref table (- i 1)) j)
               (vector-ref (vector-ref table i) (- j 1)))
            (backtrack (- i 1) j acc))
           (else
            (backtrack i (- j 1) acc)))))))

  ;; Emit unified diff output with ANSI colors.
  (define diff-lines
    (lambda (lines1 lines2 lcs)
      (let loop ((l1 lines1) (l2 lines2) (common lcs))
        (cond
         ;; All consumed
         ((and (null? l1) (null? l2)) (void))
         ;; Remaining removals
         ((null? l2)
          (for-each (lambda (line)
                      (display ansi-red)
                      (display "- ")
                      (display line)
                      (display ansi-reset)
                      (newline))
                    l1))
         ;; Remaining additions
         ((null? l1)
          (for-each (lambda (line)
                      (display ansi-green)
                      (display "+ ")
                      (display line)
                      (display ansi-reset)
                      (newline))
                    l2))
         ;; Context line (matches LCS)
         ((and (not (null? common))
               (string=? (car l1) (car common))
               (string=? (car l2) (car common)))
          (display "  ")
          (display (car l1))
          (newline)
          (loop (cdr l1) (cdr l2) (cdr common)))
         ;; Removed line (in l1 but not next common)
         ((or (null? common) (not (string=? (car l1) (car common))))
          (display ansi-red)
          (display "- ")
          (display (car l1))
          (display ansi-reset)
          (newline)
          (loop (cdr l1) l2 common))
         ;; Added line (in l2 but not next common)
         (else
          (display ansi-green)
          (display "+ ")
          (display (car l2))
          (display ansi-reset)
          (newline)
          (loop l1 (cdr l2) common))))))

  ;; ================================================================
  ;; Dependency hash-change detection
  ;; ================================================================

  ;; Extract (name-or-hash . hash) pairs from a normalized tree.
  (define extract-named-refs
    (lambda (tree hash->name)
      (let ((hashes (extract-refs tree)))
        (map (lambda (h)
               (cons (or (hash->name h) (string->symbol h)) h))
             hashes))))

  ;; Compare two ref lists. Report names where the hash changed.
  (define diff-dependency-hashes
    (lambda (refs1 refs2 short-hash)
      (let ((changed '()))
        ;; For each name in refs1, check if refs2 has the same name
        ;; with a different hash.
        (for-each
         (lambda (r1)
           (let ((name (car r1))
                 (hash1 (cdr r1)))
             (for-each
              (lambda (r2)
                (when (and (eq? name (car r2))
                           (not (string=? hash1 (cdr r2))))
                  (unless (assq name changed)
                    (set! changed
                      (cons (list name hash1 (cdr r2)) changed)))))
              refs2)))
         refs1)
        (unless (null? changed)
          (display ansi-cyan)
          (display "Changed dependencies (same name, different hash):")
          (display ansi-reset)
          (newline)
          (for-each
           (lambda (entry)
             (let ((name (car entry))
                   (h1 (cadr entry))
                   (h2 (caddr entry)))
               (display "  ")
               (display name)
               (display ": ")
               (display (short-hash h1))
               (display " -> ")
               (display (short-hash h2))
               (newline)))
           (reverse changed))))))

  ;; ================================================================
  ;; bb diff — pretty-printed text diff with ANSI colors
  ;; ================================================================

  (define diff-trees
    (lambda (t1 t2 path)
      (cond
       ((equal? t1 t2) (void))
       ((and (pair? t1) (pair? t2))
        (diff-trees (car t1) (car t2) (string-append path "/car"))
        (diff-trees (cdr t1) (cdr t2) (string-append path "/cdr")))
       (else
        (display "  at ")
        (display path)
        (display ": ")
        (write t1)
        (display " -> ")
        (write t2)
        (newline)))))

  (define command-diff
    (lambda (arguments)
      (when (< (length arguments) 2)
        (display "bb diff: usage: bb diff <name1|hash1> <name2|hash2>\n"
                 (current-error-port))
        (exit 1))
      (let* ((name1 (car arguments))
             (name2 (cadr arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (hash1 (let-values (((h l m) (resolve-ref name-index root name1))) h))
             (hash2 (let-values (((h l m) (resolve-ref name-index root name2))) h))
             (short-hash (store-make-short-hash (store-list-all-stored-hashes root))))
        (if (string=? hash1 hash2)
            (display "Identical (same hash).\n")
            (let* ((text1 (mobius-pretty-string root name-index hash1 name1))
                   (text2 (mobius-pretty-string root name-index hash2 name2))
                   (lines1 (string-split-lines text1))
                   (lines2 (string-split-lines text2))
                   (common (lcs-lines lines1 lines2)))
              ;; Header
              (display ansi-cyan)
              (display "--- ")
              (display name1)
              (display " [")
              (display (short-hash hash1))
              (display "]")
              (newline)
              (display "+++ ")
              (display name2)
              (display " [")
              (display (short-hash hash2))
              (display "]")
              (newline)
              (display ansi-reset)
              ;; Diff body
              (if (equal? lines1 lines2)
                  (display "Surface code identical.\n")
                  (diff-lines lines1 lines2 common))
              ;; Hash-changed dependencies
              (let* ((hash->name (make-hash->name name-index root))
                     (body1 (store-load-combiner root hash1))
                     (body2 (store-load-combiner root hash2))
                     (refs1 (extract-named-refs body1 hash->name))
                     (refs2 (extract-named-refs body2 hash->name)))
                (diff-dependency-hashes refs1 refs2 short-hash)))))))

  ;; ================================================================
  ;; bb refactor — propagate hash changes through the caller graph
  ;; ================================================================

  ;; Replace (mobius-constant-ref old-hash) with (mobius-constant-ref new-hash)
  (define replace-ref
    (lambda (tree old-hash new-hash)
      (cond
       ((and (pair? tree)
             (eq? 'mobius-constant-ref (car tree))
             (pair? (cdr tree))
             (string? (cadr tree))
             (string=? (cadr tree) old-hash))
        (list 'mobius-constant-ref new-hash))
       ((pair? tree)
        (cons (replace-ref (car tree) old-hash new-hash)
              (replace-ref (cdr tree) old-hash new-hash)))
       (else tree))))

  (define command-refactor
    (lambda (arguments)
      (when (< (length arguments) 3)
        (display "bb refactor: usage: bb refactor <root> <old> <new> [<at>]  (names or hashes)\n"
                 (current-error-port))
        (exit 1))
      (let* ((root-name (car arguments))
             (old-name (cadr arguments))
             (new-name (caddr arguments))
             (at-name (if (> (length arguments) 3) (cadddr arguments) #f))
             (store-root (store-find-root (current-directory)))
             (name-index (store-build-name-index store-root))
             (root-hash (let-values (((h l m) (resolve-ref name-index store-root root-name))) h))
             (old-hash (let-values (((h l m) (resolve-ref name-index store-root old-name))) h))
             (new-hash (let-values (((h l m) (resolve-ref name-index store-root new-name))) h))
             (at-hash (and at-name
                           (let-values (((h l m) (resolve-ref name-index store-root at-name))) h)))
             (author (store-config-author store-root)))
        ;; Use a worklist for cascading updates
        ;; If <at> is given, only replace in that specific combiner
        ;; Otherwise replace in all combiners within the root tree
        (let ((worklist (list (cons old-hash new-hash)))
              (updated 0)
              ;; Collect hashes reachable from root for scoping
              (root-tree-hashes
               (let collect ((hash root-hash) (seen '()))
                 (if (member hash seen)
                     seen
                     (guard (condition (#t (cons hash seen)))
                       (let* ((body (store-load-combiner store-root hash))
                              (deps (extract-refs body)))
                         (let loop ((remaining deps)
                                    (acc (cons hash seen)))
                           (if (null? remaining)
                               acc
                               (loop (cdr remaining)
                                     (collect (car remaining) acc))))))))))
          (let loop ()
            (unless (null? worklist)
              (let* ((pair (car worklist))
                     (oh (car pair))
                     (nh (cdr pair)))
                (set! worklist (cdr worklist))
                (for-each
                 (lambda (entry)
                   (let ((entry-hash (cdr entry)))
                     ;; Only process entries within the root tree
                     (when (member entry-hash root-tree-hashes)
                       ;; If <at> is given, only touch that specific combiner
                       (when (or (not at-hash)
                                 (string=? entry-hash at-hash))
                         (let* ((body (store-load-combiner store-root entry-hash))
                                (checks (store-load-checks store-root entry-hash))
                                (deps (extract-refs body)))
                           (when (member oh deps)
                             (let* ((new-body (replace-ref body oh nh))
                                    (serialized (scheme-write-value new-body))
                                    (new-entry-hash (sha256-string serialized)))
                               ;; Store updated combiner
                               (store-combiner! store-root new-entry-hash
                                                new-body)
                               ;; Copy mapping
                               (let ((map-data
                                      (store-load-first-mapping store-root entry-hash)))
                                 (store-mapping! store-root new-entry-hash
                                                 (cdr (assq 'language map-data))
                                                 (cdr (assq 'mapping map-data))
                                                 (let ((d (assq 'doc map-data)))
                                                   (if d (cdr d) ""))))
                               ;; Record lineage with checks carried forward
                               (store-record-lineage! store-root new-entry-hash author
                                                "refactor" entry-hash #f #f
                                                (if (null? checks) #f checks))
                               ;; Cascade: propagate new hash upward
                               (unless (string=? entry-hash new-entry-hash)
                                 (set! worklist
                                   (cons (cons entry-hash new-entry-hash) worklist)))
                               (set! updated (+ updated 1))
                               (display "  refactored: ")
                               (display (car entry))
                               (display " -> ")
                               (display new-entry-hash)
                               (display "\n"))))))))
                 name-index)
                (loop))))
          (display updated)
          (display " combiner(s) refactored.\n")))))

  ;; ================================================================
  ;; bb review — mark combiners as reviewed
  ;; ================================================================

  (define command-review
    (lambda (arguments)
      (when (null? arguments)
        (display "bb review: missing name or hash\n" (current-error-port))
        (exit 1))
      (let* ((root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (author (store-config-author root)))
        (for-each
         (lambda (name)
           (let ((hash (let-values (((h l m) (resolve-ref name-index root name))) h)))
             (if (store-is-reviewed? root hash)
                 (begin
                   (display "  already reviewed: ")
                   (display name)
                   (newline))
                 (begin
                   (store-mark-reviewed! root hash author)
                   (display "  reviewed: ")
                   (display name)
                   (newline)))))
         arguments))))

  ;; ================================================================
  ;; bb search — search over combiner content and names
  ;; ================================================================

  (define command-search
    (lambda (arguments)
      (when (null? arguments)
        (display "bb search: missing query\n" (current-error-port))
        (exit 1))
      (let* ((query (car arguments))
             (root (store-find-root (current-directory)))
             (all-hashes (store-list-all-stored-hashes root))
             (short-hash (store-make-short-hash all-hashes))
             (found 0))
        (for-each
         (lambda (function-hash)
           (guard (exn (#t (void)))
             (let* ((mappings-dir (store-path-join (store-combiner-directory root function-hash)
                                             "mappings"))
                    (map-files (store-find-all-map-files mappings-dir)))
               (for-each
                (lambda (mf)
                  (guard (exn (#t (void)))
                    (let* ((content (call-with-input-file mf get-string-all))
                           (mapping-hash (sha256-string content))
                           (map-data (read (open-input-string content)))
                           (mapping (cdr (assq 'mapping map-data)))
                           (lang (cdr (assq 'language map-data)))
                           (name-entry (assv 0 mapping))
                           (self-name (if name-entry (cdr name-entry) #f)))
                      (when (or (and self-name (string-contains? self-name query))
                                (string-contains? function-hash query)
                                (string-contains? (short-hash function-hash) query)
                                (exists (lambda (e)
                                          (and (pair? e)
                                               (string? (cdr e))
                                               (string-contains? (cdr e) query)))
                                        mapping))
                        (display "  ")
                        (display (or self-name "?"))
                        (display "@")
                        (display (short-hash function-hash))
                        (display "@")
                        (display lang)
                        (display "@")
                        (display (short-hash mapping-hash))
                        (display "\n")
                        (set! found (+ found 1))))))
                map-files))))
         all-hashes)
        (display found)
        (display " result(s).\n"))))

  ;; ================================================================
  ;; bb resolve — resolve a ref to its full spec(s)
  ;; ================================================================

  (define command-resolve
    (lambda (arguments)
      (when (null? arguments)
        (display "bb resolve: missing ref\n" (current-error-port))
        (exit 1))
      (let* ((ref-string (car arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (all-hashes (store-list-all-stored-hashes root))
             (short-hash (store-make-short-hash all-hashes)))
        (guard (exn
                (#t
                 (display "not found: " (current-error-port))
                 (display ref-string (current-error-port))
                 (newline (current-error-port))
                 (exit 1)))
          (let-values (((combiner-hash lang mapping-prefix)
                        (resolve-ref name-index root ref-string)))
            ;; List all mappings for this combiner, filtered by lang/mapping constraints
            (let* ((mappings-dir (store-path-join (store-combiner-directory root combiner-hash)
                                            "mappings"))
                   (map-files (store-find-all-map-files mappings-dir))
                   (results '()))
              (for-each
               (lambda (mf)
                 (guard (exn (#t (void)))
                   (let* ((content (call-with-input-file mf get-string-all))
                          (mapping-hash (sha256-string content))
                          (map-data (read (open-input-string content)))
                          (mapping (cdr (assq 'mapping map-data)))
                          (map-lang (cdr (assq 'language map-data)))
                          (name-entry (assv 0 mapping))
                          (raw-name (if name-entry (cdr name-entry) "?"))
                          (self-name (car (string-split-at-sign raw-name)))
                          (map-short (short-hash mapping-hash)))
                     ;; Apply lang filter if specified
                     (when (or (not lang) (string=? lang map-lang))
                       ;; Apply mapping-prefix filter if specified
                       (when (or (not mapping-prefix)
                                 (and (>= (string-length map-short)
                                          (string-length mapping-prefix))
                                      (string=? (substring map-short 0
                                                           (string-length mapping-prefix))
                                                mapping-prefix)))
                         (set! results
                           (cons (string-append self-name "@"
                                                (short-hash combiner-hash) "@"
                                                map-lang "@"
                                                map-short)
                                 results)))))))
               map-files)
              (cond
               ((null? results)
                (display "not found: " (current-error-port))
                (display ref-string (current-error-port))
                (newline (current-error-port))
                (exit 1))
               ((= (length results) 1)
                (display (car results))
                (newline))
               (else
                (for-each
                 (lambda (r)
                   (display "  ")
                   (display r)
                   (newline))
                 (reverse results))))
              ;; Show shadowed entries: older combiners that shared this base name
              (let* ((base-name (car (string-split-at-sign ref-string)))
                     (prefix (string-append base-name "@"))
                     (shadowed (filter (lambda (e)
                                         (let ((k (car e)) (h (cdr e)))
                                           (and (not (string=? h combiner-hash))
                                                (>= (string-length k) (string-length prefix))
                                                (string=? (substring k 0 (string-length prefix))
                                                          prefix))))
                                       name-index)))
                (when (not (null? shadowed))
                  (for-each
                   (lambda (entry)
                     (display "  shadowed: ")
                     (display (car entry))
                     (newline))
                   shadowed)))))))))

  ;; ================================================================
  ;; bb worklog — time-stamped work log entries
  ;; ================================================================

  (define command-worklog
    (lambda (arguments)
      (when (null? arguments)
        (display "bb worklog: missing name or hash\n" (current-error-port))
        (exit 1))
      (let* ((name (car arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root))
             (hash (let-values (((h l m) (resolve-ref name-index root name))) h)))
        (if (> (length arguments) 1)
            ;; Add entry — join all remaining arguments as message
            (let ((message (let loop ((parts (cdr arguments)) (acc ""))
                             (if (null? parts)
                                 acc
                                 (loop (cdr parts)
                                       (if (string=? acc "")
                                           (car parts)
                                           (string-append acc " " (car parts))))))))
              (store-add-worklog-entry! root hash message)
              (display "  worklog entry added for ")
              (display name)
              (newline))
            ;; View entries
            (let ((entries (store-list-worklog-entries root hash)))
              (if (null? entries)
                  (begin
                    (display "No worklog entries for ")
                    (display name)
                    (display ".\n"))
                  (for-each
                   (lambda (entry)
                     (display "=== ")
                     (display (cdr (assq 'timestamp entry)))
                     (display " ===\n")
                     (display (cdr (assq 'message entry)))
                     (newline)
                     (newline))
                   entries)))))))

  ;; ================================================================
  ;; bb validate — verify store integrity
  ;; ================================================================

  (define command-validate
    (lambda ()
      (let* ((root (store-find-root (current-directory)))
             (stored-hashes (store-list-all-stored-hashes root))
             (short-hash (store-make-short-hash stored-hashes))
             (errors 0))
        ;; Verify each stored combiner's hash matches its content
        (for-each
         (lambda (fhash)
           (let* ((body (store-load-combiner root fhash))
                  (serialized (scheme-write-value body))
                  (computed-hash (sha256-string serialized)))
             (unless (string=? fhash computed-hash)
               (display "  ERROR: hash mismatch [")
               (display (short-hash fhash))
               (display "]\n    computed: ")
               (display (short-hash computed-hash))
               (display "\n")
               (set! errors (+ errors 1)))))
         stored-hashes)
        (if (= errors 0)
            (begin
              (display "Store is valid. ")
              (display (length stored-hashes))
              (display " combiner(s) stored.\n"))
            (begin
              (display errors)
              (display " error(s) found.\n"))))))

  ;; ================================================================
  ;; Per-remote visibility — bb remote publish / bb remote stop
  ;; ================================================================

  ;; Walk dependency closure: start from root-hash, follow tree.scm refs,
  ;; and include check hashes recorded in the latest committed lineage.
  ;; Returns list of hashes (root first, deps after), no duplicates.
  (define compute-publish-closure
    (lambda (root start-hash)
      (let ((seen (make-hashtable string-hash string=?))
            (order '()))
        (let walk ((h start-hash))
          (unless (hashtable-ref seen h #f)
            (hashtable-set! seen h #t)
            (set! order (cons h order))
            (guard (exn (#t (void)))
              (let ((body (store-load-combiner root h)))
                (for-each walk (extract-refs body))))
            (for-each walk (store-load-checks root h))))
        (reverse order))))

  ;; Set of combiner hashes to push to <remote-name>: every committed combiner
  ;; explicitly published to that remote, plus the transitive closure of their
  ;; tree refs and lineage checks (committed only — uncommitted deps are
  ;; skipped silently). Order is unspecified.
  (define push-closure-for-remote
    (lambda (root remote-name name-index)
      (let* ((seen (make-hashtable string-hash string=?))
             (visit
              (lambda (fhash)
                (let visit ((fhash fhash))
                  (when (and fhash
                             (store-has-committed-lineage? root fhash)
                             (not (hashtable-ref seen fhash #f)))
                    (hashtable-set! seen fhash #t)
                    (guard (exn (#t (void)))
                      (let ((body (store-load-combiner root fhash)))
                        (for-each visit (extract-refs body))))
                    (for-each visit (store-load-checks root fhash)))))))
        (for-each
         (lambda (entry)
           (let ((fhash (cdr entry)))
             (when (store-is-published? root remote-name fhash)
               (visit fhash))))
         name-index)
        (vector->list (hashtable-keys seen)))))

  (define resolve-remote-or-die
    (lambda (root remote-name verb)
      (let ((remote-entry (assoc remote-name (store-config-remotes root))))
        (unless remote-entry
          (display (string-append "bb remote " verb ": unknown remote '"
                                  remote-name "'. Use 'bb remote add' first.\n")
                   (current-error-port))
          (exit 1))
        remote-entry)))

  (define command-remote-publish
    (lambda (root rest)
      (when (or (null? rest) (null? (cdr rest)))
        (display "bb remote publish: usage: bb remote publish <remote> <ref>\n"
                 (current-error-port))
        (exit 1))
      (let* ((remote-name (car rest))
             (ref (cadr rest)))
        (resolve-remote-or-die root remote-name "publish")
        (let* ((name-index (store-build-name-index root))
               (author (store-config-author root))
               (hash->name (make-hash->name name-index root))
               (short-hash (store-make-short-hash (store-list-all-stored-hashes root))))
          (let-values (((target-hash _l _m) (resolve-ref name-index root ref)))
            (unless (store-has-committed-lineage? root target-hash)
              (display "bb remote publish: ref has no committed lineage. Run 'bb commit' first.\n"
                       (current-error-port))
              (exit 1))
            (let* ((closure (compute-publish-closure root target-hash))
                   (unpublished (filter (lambda (h)
                                          (not (store-is-published? root remote-name h)))
                                        closure))
                   (deps (cdr closure)))
              (cond
               ((null? unpublished)
                (display "Already published to ")
                (display remote-name)
                (display ".\n"))
               ((null? deps)
                (store-mark-published! root remote-name target-hash author)
                (display "Published ")
                (display (or (hash->name target-hash) (short-hash target-hash)))
                (display " to ")
                (display remote-name)
                (newline))
               (else
                (display "Closure to publish to ")
                (display remote-name)
                (display ":\n")
                (for-each
                 (lambda (h)
                   (display "  ")
                   (display (or (hash->name h) (short-hash h)))
                   (display " [")
                   (display (short-hash h))
                   (display "]")
                   (when (store-is-published? root remote-name h)
                     (display " (already public)"))
                   (newline))
                 closure)
                (flush-output-port (current-output-port))
                (display "\nPublish closure (")
                (display (length unpublished))
                (display " ref(s))? [Y/n] ")
                (flush-output-port (current-output-port))
                (let* ((response (edit-read-tty-line))
                       (publish-deps?
                        (or (not (string? response))
                            (string=? response "")
                            (string=? response "y")
                            (string=? response "Y")
                            (string=? response "yes"))))
                  (cond
                   (publish-deps?
                    (for-each
                     (lambda (h) (store-mark-published! root remote-name h author))
                     unpublished)
                    (display (length unpublished))
                    (display " ref(s) published to ")
                    (display remote-name)
                    (display ".\n"))
                   (else
                    (store-mark-published! root remote-name target-hash author)
                    (display "Published only ")
                    (display (or (hash->name target-hash) (short-hash target-hash)))
                    (display " to ")
                    (display remote-name)
                    (display ". Closure incomplete — push will leave dangling references.\n"
                             (current-error-port)))))))))))))

  (define command-remote-stop
    (lambda (root rest)
      (when (or (null? rest) (null? (cdr rest)))
        (display "bb remote stop: usage: bb remote stop <remote> <ref>\n"
                 (current-error-port))
        (exit 1))
      (let* ((remote-name (car rest))
             (ref (cadr rest)))
        (resolve-remote-or-die root remote-name "stop")
        (let* ((name-index (store-build-name-index root))
               (hash->name (make-hash->name name-index root))
               (short-hash (store-make-short-hash (store-list-all-stored-hashes root))))
          (let-values (((target-hash _l _m) (resolve-ref name-index root ref)))
            (cond
             ((store-is-published? root remote-name target-hash)
              (store-unmark-published! root remote-name target-hash)
              (display "Stopped publishing ")
              (display (or (hash->name target-hash) (short-hash target-hash)))
              (display " to ")
              (display remote-name)
              (newline))
             (else
              (display "Not currently published to ")
              (display remote-name)
              (display ".\n"))))))))

  ;; ================================================================
  ;; bb anchor — request or upgrade an OpenTimestamps proof for a ref
  ;;
  ;; Anchors the latest committed lineage record and tree.scm.
  ;; State is encoded by which proof file exists next to the artifact:
  ;;   <artifact>.ots          — confirmed (Bitcoin-anchored)
  ;;   <artifact>.ots.pending  — calendar receipt, awaiting confirmation
  ;;   neither                 — not yet anchored
  ;; Action chosen automatically per artifact:
  ;;   confirmed → skip
  ;;   pending   → ots upgrade, then ots verify; on success rename to .ots
  ;;   none      → ots stamp, then ots upgrade, then ots verify
  ;; Requires the `ots` CLI on PATH.
  ;; ================================================================

  (define ots-available?
    (lambda ()
      (= 0 (system "command -v ots > /dev/null 2>&1"))))

  (define ots-stamp!
    (lambda (path)
      (= 0 (system (string-append "ots stamp " path " > /dev/null 2>&1")))))

  (define ots-upgrade!
    (lambda (path)
      (= 0 (system (string-append "ots upgrade " path " > /dev/null 2>&1")))))

  (define ots-verify!
    (lambda (path)
      (= 0 (system (string-append "ots verify " path " > /dev/null 2>&1")))))

  ;; Smart anchor for one artifact path. Returns a status symbol.
  (define anchor-artifact!
    (lambda (artifact-path)
      (let ((final-path (string-append artifact-path ".ots"))
            (pending-path (string-append artifact-path ".ots.pending")))
        (cond
         ((not (file-exists? artifact-path))
          'missing)
         ((file-exists? final-path)
          'already-anchored)
         ((file-exists? pending-path)
          (ots-upgrade! pending-path)
          (cond
           ((ots-verify! pending-path)
            (rename-file pending-path final-path)
            'upgraded)
           (else 'still-pending)))
         (else
          (cond
           ((not (ots-stamp! artifact-path)) 'stamp-failed)
           (else
            ;; ots stamp writes <artifact>.ots; mark pending until verified.
            (when (file-exists? final-path)
              (rename-file final-path pending-path))
            (ots-upgrade! pending-path)
            (cond
             ((ots-verify! pending-path)
              (rename-file pending-path final-path)
              'anchored)
             (else 'requested)))))))))

  (define latest-committed-lineage-path
    (lambda (root function-hash)
      (let ((files (store-list-committed-files root function-hash)))
        (cond
         ((null? files) #f)
         (else
          (store-path-join (store-combiner-directory root function-hash)
                           "lineage"
                           (car (sort string>? files))))))))

  ;; Return the content-hash of the predecessor's most recent committed lineage
  ;; record (i.e. the largest 'committed timestamp among committed lineage files).
  ;; Returns #f if no committed lineage exists.
  (define latest-committed-lineage-hash
    (lambda (root function-hash)
      (let* ((files (store-list-committed-files root function-hash))
             (records (map (lambda (f)
                             (cons f (load-lineage-record root function-hash f)))
                           files))
             (sorted (sort (lambda (a b)
                             (string>? (cdr (assq 'committed (cdr a)))
                                       (cdr (assq 'committed (cdr b)))))
                           records)))
        (cond
         ((null? sorted) #f)
         (else
          (let* ((filename (car (car sorted)))
                 (suffix-len (string-length ".committed.scm")))
            (substring filename 0 (- (string-length filename) suffix-len))))))))

  ;; Checks bb edit should pre-populate. If the most recent lineage record is
  ;; a committed one, return its checks unchanged. If there are wip records
  ;; created after the last committed record, fold them in chronological order:
  ;;   - retract-checks records remove hashes
  ;;   - records with a 'checks field overwrite the current set
  ;;   - other records are ignored
  ;; This matches the user's mental model: the editor shows what was last
  ;; asserted (committed or in-flight), not the cumulative union of history.
  (define latest-committed-lineage-checks
    (lambda (root function-hash)
      (let* ((committed-files (store-list-committed-files root function-hash))
             (committed-records
              (map (lambda (f) (load-lineage-record root function-hash f))
                   committed-files))
             (committed-add-records
              (filter (lambda (r)
                        (let ((rel (assq 'relation r)))
                          (or (not rel)
                              (not (string=? (cdr rel) "retract-checks")))))
                      committed-records))
             (latest-committed
              (cond
               ((null? committed-add-records) #f)
               (else
                (car (sort (lambda (a b)
                             (string>? (cdr (assq 'committed a))
                                       (cdr (assq 'committed b))))
                           committed-add-records)))))
             (committed-cutoff
              (and latest-committed (cdr (assq 'committed latest-committed))))
             (initial-checks
              (if latest-committed
                  (let ((c (assq 'checks latest-committed)))
                    (if c (cdr c) '()))
                  '()))
             (wip-files (store-list-wip-files root function-hash))
             (wip-records
              (map (lambda (f) (load-lineage-record root function-hash f))
                   wip-files))
             (wip-newer
              (filter (lambda (r)
                        (let ((c (assq 'created r)))
                          (and c
                               (or (not committed-cutoff)
                                   (string>? (cdr c) committed-cutoff)))))
                      wip-records))
             (wip-sorted
              (sort (lambda (a b)
                      (let ((ta (cdr (assq 'created a)))
                            (tb (cdr (assq 'created b))))
                        (cond
                         ((string<? ta tb) #t)
                         ((string<? tb ta) #f)
                         ;; Within ties, the no-checks intermediate write must
                         ;; precede the with-checks final write so the latter
                         ;; overwrites it.
                         (else
                          (and (not (assq 'checks a))
                               (assq 'checks b))))))
                    wip-newer)))
        (cond
         ((null? wip-sorted) initial-checks)
         (else
          (fold-left
           (lambda (current record)
             (let ((rel (assq 'relation record)))
               (cond
                ((and rel (string=? (cdr rel) "retract-checks"))
                 (let ((rch (assq 'retract-checks record)))
                   (if rch
                       (filter (lambda (h) (not (member h (cdr rch)))) current)
                       current)))
                (else
                 (let ((c (assq 'checks record)))
                   (if c (cdr c) current))))))
           initial-checks
           wip-sorted))))))

  (define command-anchor
    (lambda (arguments)
      (when (null? arguments)
        (display "bb anchor: missing ref\n" (current-error-port))
        (exit 1))
      (unless (ots-available?)
        (display "bb anchor: 'ots' CLI not found on PATH. Install opentimestamps-client.\n"
                 (current-error-port))
        (exit 1))
      (let* ((ref (car arguments))
             (root (store-find-root (current-directory)))
             (name-index (store-build-name-index root)))
        (let-values (((target-hash _l _m) (resolve-ref name-index root ref)))
          (unless (store-has-committed-lineage? root target-hash)
            (display "bb anchor: ref has no committed lineage. Run 'bb commit' first.\n"
                     (current-error-port))
            (exit 1))
          (let ((tree-path (store-combiner-tree-path root target-hash))
                (lineage-path (latest-committed-lineage-path root target-hash)))
            (for-each
             (lambda (path)
               (when path
                 (let ((status (anchor-artifact! path)))
                   (display "  ")
                   (display (case status
                              ((already-anchored) "anchored ✓")
                              ((upgraded)         "upgraded → confirmed ✓")
                              ((anchored)         "anchored ✓ (confirmed immediately)")
                              ((requested)        "requested (pending Bitcoin confirmation)")
                              ((still-pending)    "still pending")
                              ((stamp-failed)     "stamp failed")
                              ((missing)          "artifact missing")
                              (else               "?")))
                   (display ": ")
                   (display path)
                   (newline))))
             (list tree-path lineage-path)))))))


  ;; ================================================================
  ;; bb remote — manage remote store endpoints
  ;; ================================================================

  (define url-scheme-valid?
    (lambda (url)
      (or (and (>= (string-length url) 7)
               (string=? (substring url 0 7) "file://"))
          (and (>= (string-length url) 10)
               (string=? (substring url 0 10) "git+ssh://"))
          (and (>= (string-length url) 12)
               (string=? (substring url 0 12) "git+https://")))))

  (define command-remote-list
    (lambda (root)
      (let ((remotes (store-config-remotes root)))
        (if (null? remotes)
            (display "No remotes configured.\n")
            (for-each
             (lambda (r)
               (display "  ")
               (display (car r))
               (display " -> ")
               (display (store-remote-entry-url r))
               (when (store-remote-entry-read-only? r)
                 (display " [read-only]"))
               (newline))
             remotes)))))

  (define command-remote-add
    (lambda (root rest)
      (let* ((read-only (and (not (null? rest))
                             (string=? (car rest) "--read-only")))
             (rest (if read-only (cdr rest) rest)))
        (when (< (length rest) 2)
          (display "bb remote add: usage: bb remote add [--read-only] <name> <url>\n"
                   (current-error-port))
          (exit 1))
        (let* ((name (car rest))
               (url (cadr rest)))
          (unless (url-scheme-valid? url)
            (display "bb remote add: URL must start with file://, git+ssh://, or git+https://\n"
                     (current-error-port))
            (exit 1))
          (let* ((remotes (store-config-remotes root))
                 (new-entry (list name
                                  (cons 'url url)
                                  (cons 'read-only read-only)))
                 (new-remotes (cons new-entry
                                    (filter (lambda (r)
                                              (not (string=? (car r) name)))
                                            remotes))))
            (store-set-config-remotes! root new-remotes)
            (display "Remote '")
            (display name)
            (display "' added -> ")
            (display url)
            (when read-only (display " [read-only]"))
            (newline))))))

  (define command-remote-remove
    (lambda (root rest)
      (when (null? rest)
        (display "bb remote remove: missing name\n" (current-error-port))
        (exit 1))
      (let* ((name (car rest))
             (remotes (store-config-remotes root))
             (new-remotes (filter (lambda (r)
                                    (not (string=? (car r) name)))
                                  remotes)))
        (store-set-config-remotes! root new-remotes)
        (display "Remote '")
        (display name)
        (display "' removed.\n"))))

  (define command-remote-push
    (lambda (root rest)
      (when (null? rest)
        (display "bb remote push: missing remote name\n" (current-error-port))
        (exit 1))
      (let* ((remote-name (car rest))
             (remotes (store-config-remotes root))
             (remote-entry (assoc remote-name remotes)))
        (unless remote-entry
          (display "bb remote push: unknown remote '")
          (display remote-name)
          (display "'. Use 'bb remote add' first.\n" (current-error-port))
          (exit 1))
        (when (store-remote-entry-read-only? remote-entry)
          (display "bb remote push: remote '")
          (display remote-name)
          (display "' is read-only\n" (current-error-port))
          (exit 1))
        (let* ((remote-path (store-remote-entry-path remote-entry))
               (name-index (store-build-name-index root))
               (hash->name (make-hash->name name-index root))
               (short-hash (store-make-short-hash (store-list-all-stored-hashes root)))
               (to-push (push-closure-for-remote root remote-name name-index))
               (count 0))
          (store-ensure-directory (store-path-join remote-path "combiners"))
          (for-each
           (lambda (fhash)
             (store-copy-combiner! root remote-path fhash)
             (set! count (+ count 1))
             (display "  pushed: ")
             (display (or (hash->name fhash) (short-hash fhash)))
             (newline))
           to-push)
          (display count)
          (display " combiner(s) pushed to ")
          (display remote-name)
          (display ".\n")))))

  (define command-remote-pull
    (lambda (root rest)
      (when (null? rest)
        (display "bb remote pull: missing remote name\n" (current-error-port))
        (exit 1))
      (let* ((remote-name (car rest))
             (remotes (store-config-remotes root))
             (remote-entry (assoc remote-name remotes)))
        (unless remote-entry
          (display "bb remote pull: unknown remote '")
          (display remote-name)
          (display "'. Use 'bb remote add' first.\n" (current-error-port))
          (exit 1))
        (let* ((remote-path (store-remote-entry-path remote-entry))
               (local-index (store-build-name-index root))
               (remote-index (store-build-name-index remote-path))
               (count 0))
          (for-each
           (lambda (entry)
             (let* ((name (car entry))
                    (fhash (cdr entry))
                    (local-entry (assoc name local-index)))
               (unless (and local-entry (string=? (cdr local-entry) fhash))
                 (store-copy-combiner! remote-path root fhash)
                 (set! count (+ count 1))
                 (display "  pulled: ")
                 (display name)
                 (newline))))
           remote-index)
          (display count)
          (display " combiner(s) pulled from ")
          (display remote-name)
          (display ".\n")))))

  (define command-remote-sync
    (lambda (root)
      (let ((remotes (store-config-remotes root)))
        (when (null? remotes)
          (display "No remotes configured. Use 'bb remote add' first.\n")
          (exit 1))
        (for-each
         (lambda (remote-entry)
           (let* ((remote-name (car remote-entry))
                  (remote-path (store-remote-entry-path remote-entry))
                  (local-index (store-build-name-index root))
                  (remote-index (store-build-name-index remote-path))
                  (pull-count 0)
                  (push-count 0))
             (display "Syncing '")
             (display remote-name)
             (display "'...\n")
             ;; Pull from remote
             (for-each
              (lambda (entry)
                (let* ((name (car entry))
                       (fhash (cdr entry))
                       (local-entry (assoc name local-index)))
                  (unless (and local-entry (string=? (cdr local-entry) fhash))
                    (store-copy-combiner! remote-path root fhash)
                    (set! pull-count (+ pull-count 1))
                    (display "  pulled: ")
                    (display name)
                    (newline))))
              remote-index)
             ;; Push to remote (if not read-only)
             (if (store-remote-entry-read-only? remote-entry)
                 (display "  Skipping push: remote is read-only.\n")
                 (let* ((name-index (store-build-name-index root))
                        (hash->name (make-hash->name name-index root))
                        (short-hash (store-make-short-hash (store-list-all-stored-hashes root)))
                        (to-push (push-closure-for-remote root remote-name name-index)))
                   (store-ensure-directory (store-path-join remote-path "combiners"))
                   (for-each
                    (lambda (fhash)
                      (store-copy-combiner! root remote-path fhash)
                      (set! push-count (+ push-count 1))
                      (display "  pushed: ")
                      (display (or (hash->name fhash) (short-hash fhash)))
                      (newline))
                    to-push)))
             (display "  ")
             (display pull-count)
             (display " pulled, ")
             (display push-count)
             (display " pushed.\n")))
         remotes))))

  (define command-remote
    (lambda (arguments)
      (when (null? arguments)
        (display "bb remote: missing subcommand (add, remove, list, push, pull, sync, publish, stop)\n"
                 (current-error-port))
        (exit 1))
      (let ((root (store-find-root (current-directory)))
            (subcmd (car arguments))
            (rest (cdr arguments)))
        (case (string->symbol subcmd)
          [(list) (command-remote-list root)]
          [(add) (command-remote-add root rest)]
          [(remove) (command-remote-remove root rest)]
          [(push) (command-remote-push root rest)]
          [(pull) (command-remote-pull root rest)]
          [(sync) (command-remote-sync root)]
          [(publish) (command-remote-publish root rest)]
          [(stop) (command-remote-stop root rest)]
          [else
           (display "bb remote: unknown subcommand '")
           (display subcmd)
           (display "'\n")]))))

  ;; ================================================================
  ;; bb mapping — view, delete, and set mapping entries
  ;; ================================================================

  (define command-mapping-list
    (lambda (root rest)
      (when (null? rest)
        (display "bb mapping list: missing ref\n" (current-error-port))
        (exit 1))
      (let* ((name-index (store-build-name-index root))
             (hash (let-values (((h l m) (resolve-ref name-index root (car rest)))) h))
             (mappings (store-list-mappings root hash))
             (hash->name (make-hash->name name-index root))
             (display-name (or (hash->name hash) (substring hash 0 12))))
        (display "Mappings for ") (display display-name)
        (display " [") (display (substring hash 0 12)) (display "]:\n")
        (if (null? mappings)
            (display "  (none)\n")
            (for-each
             (lambda (entry)
               (let* ((mapping-hash (car entry))
                      (map-data (cdr entry))
                      (lang (let ((l (assq 'language map-data)))
                              (if l (cdr l) "?")))
                      (mapping (let ((m (assq 'mapping map-data)))
                                 (if m (cdr m) '())))
                      (name-entry (assv 0 mapping))
                      (name (if name-entry (cdr name-entry) "?")))
                 (display "  ")
                 (display (substring mapping-hash 0 12))
                 (display "  lang=") (display lang)
                 (display "  name=") (display name)
                 (for-each
                  (lambda (pair)
                    (when (> (car pair) 0)
                      (display "  ") (display (car pair))
                      (display "=") (display (cdr pair))))
                  mapping)
                 (newline)))
             mappings)))))

  (define command-mapping-delete
    (lambda (root rest)
      (when (null? rest)
        (display "bb mapping delete: usage: bb mapping delete <ref>\n"
                 (current-error-port))
        (display "  <ref> must identify a mapping (e.g. name@lang@mapHash or hash@mapHash)\n"
                 (current-error-port))
        (exit 1))
      (let* ((name-index (store-build-name-index root)))
        (let-values (((combiner-hash _lang prefix) (resolve-ref name-index root (car rest))))
          (unless prefix
            (display "bb mapping delete: ref must include a mapping hash. Use 'bb mapping list <ref>' to see them.\n"
                     (current-error-port))
            (exit 1))
          (let* ((mappings (store-list-mappings root combiner-hash))
                 (matches (filter (lambda (entry)
                                    (and (>= (string-length (car entry)) (string-length prefix))
                                         (string=? prefix
                                                   (substring (car entry) 0 (string-length prefix)))))
                                  mappings)))
            (cond
             ((null? matches)
              (display "bb mapping delete: no mapping matching prefix '")
              (display prefix) (display "'\n" (current-error-port))
              (exit 1))
             ((> (length matches) 1)
              (display "bb mapping delete: ambiguous prefix '")
              (display prefix) (display "' matches ")
              (display (length matches)) (display " mappings\n" (current-error-port))
              (exit 1))
             (else
              (let ((mapping-hash (caar matches)))
                (store-delete-mapping! root combiner-hash mapping-hash)
                (display "deleted mapping ") (display (substring mapping-hash 0 12))
                (newline)))))))))

  (define command-mapping-set
    (lambda (root rest)
      (when (< (length rest) 3)
        (display "bb mapping set: usage: bb mapping set <ref> <key> <value>\n"
                 (current-error-port))
        (display "  key is an integer (0=self-name, 1+=parameter names)\n"
                 (current-error-port))
        (exit 1))
      (let* ((name-index (store-build-name-index root))
             (combiner-hash (let-values (((h l m) (resolve-ref name-index root (car rest)))) h))
             (key (let ((k (string->number (cadr rest))))
                    (unless k
                      (display "bb mapping set: key must be an integer\n" (current-error-port))
                      (exit 1))
                    k))
             (value (caddr rest))
             ;; Load the current preferred mapping
             (map-data (guard (exn (#t #f))
                         (store-load-preferred-mapping root combiner-hash)))
             (old-mapping (if map-data (cdr (assq 'mapping map-data)) '()))
             (old-lang (if map-data (cdr (assq 'language map-data)) "en"))
             (old-doc (if map-data
                          (let ((d (assq 'doc map-data))) (if d (cdr d) ""))
                          ""))
             ;; Update the mapping alist
             (new-mapping (cons (cons key value)
                                (filter (lambda (e) (not (= (car e) key)))
                                        old-mapping)))
             ;; Store as a new mapping
             (new-hash (store-mapping! root combiner-hash old-lang new-mapping old-doc)))
        ;; Delete the old mapping if it exists
        (when map-data
          (let ((mappings (store-list-mappings root combiner-hash)))
            (for-each
             (lambda (entry)
               (unless (string=? (car entry) new-hash)
                 (let ((entry-lang (let ((l (assq 'language (cdr entry))))
                                     (if l (cdr l) ""))))
                   (when (string=? entry-lang old-lang)
                     (store-delete-mapping! root combiner-hash (car entry))))))
             mappings)))
        (display "mapping updated: position ")
        (display key) (display " = \"") (display value)
        (display "\" [") (display (substring new-hash 0 12))
        (display "]\n"))))

  (define command-mapping
    (lambda (arguments)
      (when (null? arguments)
        (display "bb mapping: missing subcommand (list, delete, set)\n"
                 (current-error-port))
        (exit 1))
      (let* ((subcmd (car arguments))
             (rest (cdr arguments))
             (root (store-find-root (current-directory))))
        (case (string->symbol subcmd)
          [(list) (command-mapping-list root rest)]
          [(delete) (command-mapping-delete root rest)]
          [(set) (command-mapping-set root rest)]
          [else
           (display "bb mapping: unknown subcommand '")
           (display subcmd)
           (display "'\n")]))))

  ;; ================================================================
  ;; Main entry point
  ;; ================================================================

  (define main
    (lambda arguments
      (let ((arguments (if (null? arguments) (cdr (command-line)) arguments)))
        (if (null? arguments)
            (print-usage)
            (let ((command (car arguments))
                  (rest (cdr arguments)))
              (cond
               ((string=? command "--help") (print-usage))
               ((string=? command "--version")
                (display "bb ")
                (display bb-version)
                (newline))
               (else (case (string->symbol command)
                [(eval) (command-eval rest)]
                [(repl) (command-repl)]
                [(add) (command-add rest)]
                [(commit) (command-commit rest)]
                [(edit) (command-edit rest)]
                [(diff) (command-diff rest)]
                [(refactor) (command-refactor rest)]
                [(resolve) (command-resolve rest)]
                [(review) (command-review rest)]
                [(search) (command-search rest)]
                [(worklog) (command-worklog rest)]
                [(validate) (command-validate)]
                [(anchor) (command-anchor rest)]
                [(mapping) (command-mapping rest)]
                [(remote) (command-remote rest)]
                [(run) (command-run rest)]
                [(status) (command-status)]
                [(show) (command-show rest)]
                [(print) (command-print rest)]
                [(tree) (command-tree rest)]
                [(caller) (command-caller rest)]
                [(check) (command-check rest)]
                [(log) (command-log rest)]
                [(store)
                 (if (null? rest)
                     (display "bb store: missing subcommand (init, info)\n")
                     (case (string->symbol (car rest))
                       [(init) (command-store-init (cdr rest))]
                       [(info) (command-store-info)]
                       [else (display "bb store: unknown subcommand\n")]))]
                [else
                 (display "bb: unknown command '")
                 (display command)
                 (display "'. Try 'bb --help'.\n")
                 (exit 1)]))))))))


  ;; ================================================================
  ;; Tests
  ;; ================================================================

  (define ~check-cli-build-argument-tree
    (lambda ()
      ;; Verify the argument tree construction used in application
      (let ((tree (build-argument-tree (list 1 2 3))))
        (assert (pair? tree))
        (assert (= 1 (car tree)))
        (assert (= 2 (car (cdr tree))))
        (assert (= 3 (car (cdr (cdr tree)))))
        (assert (mobius-nil? (cdr (cdr (cdr tree))))))))

  (define ~check-cli-mobius-write-surface
    (lambda ()
      ;; Test surface writer output
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (mobius-write-surface 42))
        (assert (equal? "42" (get-output-string port))))
      ;; Test pattern syntax: ,x
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (mobius-write-surface '(mobius-unquote x)))
        (assert (equal? ",x" (get-output-string port))))
      ;; Test catamorphic syntax: ,(x)
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (mobius-write-surface '(mobius-unquote-recurse tail)))
        (assert (equal? ",(tail)" (get-output-string port))))
      ;; Test wildcard: ,_
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (mobius-write-surface '(mobius-unquote _)))
        (assert (equal? ",_" (get-output-string port))))
      ;; Test list with patterns
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (mobius-write-surface (list 'gamma
                                     (list (list 'mobius-unquote 'x)
                                           (list '+ 'x 1)))))
        (let ((result (get-output-string port)))
          (assert (string? result))
          ;; Should contain ,x
          (assert (string-contains? result ",x"))))))

  (define ~check-cli-replace-ref
    (lambda ()
      ;; Test replace-ref for refactoring
      (let* ((tree '(begin (mobius-constant-ref "abc123") (mobius-constant-ref "def456")))
             (result (replace-ref tree "abc123" "new789")))
        (assert (equal? '(begin (mobius-constant-ref "new789") (mobius-constant-ref "def456"))
                         result)))
      ;; Test nested replacement
      (let* ((tree '((mobius-constant-ref "old") . ((mobius-constant-ref "old"))))
             (result (replace-ref tree "old" "new")))
        (assert (equal? '((mobius-constant-ref "new") . ((mobius-constant-ref "new")))
                         result)))
      ;; Test no match
      (let* ((tree '(+ 1 2))
             (result (replace-ref tree "old" "new")))
        (assert (equal? '(+ 1 2) result)))))

  (define ~check-cli-diff-trees
    (lambda ()
      ;; Test identical trees produce no output
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (diff-trees '(a b c) '(a b c) "root"))
        (assert (equal? "" (get-output-string port))))
      ;; Test different trees produce output
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (diff-trees '(a b) '(a c) "root"))
        (let ((result (get-output-string port)))
          (assert (> (string-length result) 0))
          (assert (string-contains? result "at "))))))

  (define ~check-cli-prepare-for-pretty
    (lambda ()
      ;; Booleans become placeholders
      (assert (eq? '%true (prepare-for-pretty #t)))
      (assert (eq? '%false (prepare-for-pretty #f)))
      ;; Standalone '() becomes %nil
      (assert (eq? '%nil (prepare-for-pretty '())))
      ;; '() in cdr position stays as list terminator
      (assert (equal? '(a b) (prepare-for-pretty '(a b))))
      ;; Nested: #t in car, '() as tail
      (assert (equal? '(%true %false) (prepare-for-pretty (list #t #f))))
      ;; '() as a car element becomes %nil
      (assert (equal? '(%nil) (prepare-for-pretty (list '()))))
      ;; Lambda with empty params preserves ()
      (assert (equal? '(lambda () 42) (prepare-for-pretty '(lambda () 42))))
      ;; String-replace works
      (assert (equal? "hello world" (string-replace "hello earth" "earth" "world")))
      (assert (equal? "aXbXc" (string-replace "a.b.c" "." "X")))
      (assert (equal? "abc" (string-replace "abc" "x" "y")))
      ;; String-split-lines
      (assert (equal? '("a" "b" "c") (string-split-lines "a\nb\nc")))
      (assert (equal? '("a" "b" "c") (string-split-lines "a\nb\nc\n")))
      (assert (equal? '("hello") (string-split-lines "hello")))))

  (define ~check-cli-post-process
    (lambda ()
      ;; Placeholder replacement
      (assert (equal? "#true" (mobius-post-process "%true")))
      (assert (equal? "#false" (mobius-post-process "%false")))
      (assert (equal? "#nil" (mobius-post-process "%nil")))
      (assert (equal? "#void" (mobius-post-process "%void")))
      (assert (equal? "#eof" (mobius-post-process "%eof")))
      ;; Unquote replacement
      (assert (equal? ",x" (mobius-post-process "(mobius-unquote x)")))
      (assert (equal? ",(rest)" (mobius-post-process "(mobius-unquote-recurse rest)")))
      ;; Wildcard
      (assert (equal? ",_" (mobius-post-process "(mobius-wildcard)")))
      ;; Combined
      (assert (equal? "(if #true ,x #nil)"
                       (mobius-post-process "(if %true (mobius-unquote x) %nil)")))))

  (define ~check-cli-lcs-lines
    (lambda ()
      ;; Identical lists
      (assert (equal? '("a" "b" "c") (lcs-lines '("a" "b" "c") '("a" "b" "c"))))
      ;; Completely different
      (assert (equal? '() (lcs-lines '("a" "b") '("c" "d"))))
      ;; Overlapping
      (assert (equal? '("b" "d") (lcs-lines '("a" "b" "c" "d") '("b" "d" "e"))))
      ;; Empty lists
      (assert (equal? '() (lcs-lines '() '("a" "b"))))
      (assert (equal? '() (lcs-lines '("a" "b") '())))
      ;; diff-lines produces output for different lines
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (diff-lines '("a" "b") '("a" "c")
                      (lcs-lines '("a" "b") '("a" "c"))))
        (let ((result (get-output-string port)))
          ;; Should contain the context line "a" and diff markers
          (assert (> (string-length result) 0))
          (assert (string-contains? result "a"))))))

  (define ~check-cli-resolve-ref
    (lambda ()
      ;; Set up a temp store with combiners
      (let* ((temp-dir (format #f "/tmp/bb-test-resolve-~a" (random 1000000))))
        (mkdir temp-dir)
        ;; Store fake combiners (just need directories with tree.scm)
        (let ((hash1 "aabb000000000000000000000000000000000000000000000000000000000001")
              (hash2 "aabb000000000000000000000000000000000000000000000000000000000002")
              (hash3 "ccdd000000000000000000000000000000000000000000000000000000000003"))
          ;; Create combiner directories with tree.scm files
          (let ((dir1 (store-path-join temp-dir "combiners" hash1))
                (dir2 (store-path-join temp-dir "combiners" hash2))
                (dir3 (store-path-join temp-dir "combiners" hash3)))
            (store-ensure-directory dir1)
            (store-ensure-directory dir2)
            (store-ensure-directory dir3)
            (call-with-output-file (store-path-join dir1 "tree.scm")
              (lambda (p) (display "()" p)))
            (call-with-output-file (store-path-join dir2 "tree.scm")
              (lambda (p) (display "()" p)))
            (call-with-output-file (store-path-join dir3 "tree.scm")
              (lambda (p) (display "()" p)))
            ;; Build a name-index with one entry
            (let ((name-index (list (cons "my-func" hash1))))
              ;; Test 1: 1-part ref — exact name match
              (let-values (((h l m) (resolve-ref name-index temp-dir "my-func")))
                (assert (string=? hash1 h))
                (assert (not l))
                (assert (not m)))
              ;; Test 2: 1-part ref — full hash match
              (let-values (((h l m) (resolve-ref name-index temp-dir hash3)))
                (assert (string=? hash3 h))
                (assert (not l))
                (assert (not m)))
              ;; Test 3: 1-part ref — unique prefix match
              (let-values (((h l m) (resolve-ref name-index temp-dir "ccdd")))
                (assert (string=? hash3 h)))
              ;; Test 4: 1-part ref — ambiguous hash prefix raises error
              (assert (guard (e (#t #t))
                       (resolve-ref name-index temp-dir "aabb")
                       #f))
              ;; Test 4b: ambiguous name auto-picks most recent by timestamp
              (let* ((short1 (substring hash1 (- (string-length hash1) 4)
                                        (string-length hash1)))
                     (short2 (substring hash2 (- (string-length hash2) 4)
                                        (string-length hash2)))
                     (disambig-index
                      (list (cons (string-append "dup@" short1) hash1)
                            (cons (string-append "dup@" short2) hash2)))
                     ;; Add lineage so hash2 is newer
                     (lin-dir1 (store-path-join dir1 "lineage"))
                     (lin-dir2 (store-path-join dir2 "lineage")))
                (store-ensure-directory lin-dir1)
                (store-ensure-directory lin-dir2)
                (call-with-output-file (store-path-join lin-dir1 "001.committed.scm")
                  (lambda (p)
                    (write '((committed . "2026-01-01T00:00:00Z")
                             (author . "test")
                             (relation . "add")) p)))
                (call-with-output-file (store-path-join lin-dir2 "001.committed.scm")
                  (lambda (p)
                    (write '((committed . "2026-03-01T00:00:00Z")
                             (author . "test")
                             (relation . "add")) p)))
                ;; Bare "dup" should resolve to hash2 (newer)
                (let-values (((h l m) (resolve-ref disambig-index temp-dir "dup")))
                  (assert (string=? hash2 h))))
              ;; Test 5: 1-part ref — no match raises error
              (assert (guard (e (#t #t))
                       (resolve-ref name-index temp-dir "ffff")
                       #f))
              ;; Test 6: 2-part ref — name@lang
              (let-values (((h l m) (resolve-ref name-index temp-dir "my-func@fr")))
                (assert (string=? hash1 h))
                (assert (string=? "fr" l))
                (assert (not m)))
              ;; Test 7: 2-part ref — hash@lang
              (let-values (((h l m) (resolve-ref name-index temp-dir "ccdd@en")))
                (assert (string=? hash3 h))
                (assert (string=? "en" l))
                (assert (not m)))
              ;; Test 8: 2-part ref — hash@mappingHash (non-alphabetic part2)
              (let-values (((h l m) (resolve-ref name-index temp-dir "ccdd@ab12")))
                (assert (string=? hash3 h))
                (assert (not l))
                (assert (string=? "ab12" m)))
              ;; Test 9: 3-part ref — name@combinerHash@lang
              (let-values (((h l m) (resolve-ref name-index temp-dir (string-append "my-func@" hash1 "@en"))))
                (assert (string=? hash1 h))
                (assert (string=? "en" l))
                (assert (not m)))
              ;; Test 10: 3-part ref — name@lang@mappingHash
              (let-values (((h l m) (resolve-ref name-index temp-dir "my-func@fr@ab12")))
                (assert (string=? hash1 h))
                (assert (string=? "fr" l))
                (assert (string=? "ab12" m)))
              ;; Test 11: 4-part ref — name@combinerHash@lang@mappingHash
              (let-values (((h l m) (resolve-ref name-index temp-dir "my-func@ccdd@kab@ff00")))
                (assert (string=? hash3 h))
                (assert (string=? "kab" l))
                (assert (string=? "ff00" m)))
              ;; Test 12: looks-like-lang? heuristic
              (assert (looks-like-lang? "en"))
              (assert (looks-like-lang? "fr"))
              (assert (looks-like-lang? "kab"))
              (assert (not (looks-like-lang? "a")))
              (assert (not (looks-like-lang? "ab12")))
              (assert (not (looks-like-lang? "abcde")))))
          ;; Cleanup
          (store-delete-directory! temp-dir)))))

  (define ~check-cli-show
    (lambda ()
      ;; Test the show pipeline using denormalize-tree directly
      ;; (command-show needs a full store on disk; we test the core logic)

      ;; Test 1: basic mode — hash->name returns symbol name
      (let* ((body '((mobius-primitive-ref 1)  ;; lambda
                     (mobius-var 1)            ;; param x
                     ((mobius-constant-ref "hash-of-add")
                      (mobius-var 1)
                      42)))
             (mapping '((1 . "x")))
             (hash->name (lambda (h)
                           (if (string=? h "hash-of-add")
                               'add
                               #f)))
             (surface (denormalize-tree body mapping hash->name))
             (prepared (prepare-for-pretty
                        (list 'define 'my-fn surface)))
             (port (open-output-string)))
        (parameterize ((pretty-line-length 72))
          (pretty-print prepared port))
        (let ((result (mobius-post-process (get-output-string port))))
          ;; Should contain 'add' as a named reference
          (assert (string-contains? result "add"))
          (assert (string-contains? result "define"))
          (assert (string-contains? result "my-fn"))))

      ;; Test 2: inline mode — hash->name returns expanded expression
      (let* ((body '((mobius-primitive-ref 1)  ;; lambda
                     (mobius-var 1)            ;; param x
                     ((mobius-constant-ref "hash-of-double")
                      (mobius-var 1))))
             (mapping '((1 . "x")))
             ;; Inline resolver returns a lambda expression for double
             (hash->name (lambda (h)
                           (if (string=? h "hash-of-double")
                               '(lambda (n) (* n 2))
                               #f)))
             (surface (denormalize-tree body mapping hash->name))
             (prepared (prepare-for-pretty
                        (list 'define 'my-fn surface)))
             (port (open-output-string)))
        (parameterize ((pretty-line-length 72))
          (pretty-print prepared port))
        (let ((result (mobius-post-process (get-output-string port))))
          ;; Should contain the inlined lambda body, not a name
          (assert (string-contains? result "lambda"))
          (assert (string-contains? result "* n 2"))
          ;; Should NOT contain the name "double" — it was inlined
          (assert (not (string-contains? result "double")))))))

  (define ~check-cli-print
    (lambda ()
      ;; Test 1: shortest-unique-prefix
      (assert (string=? "aa11"
                         (shortest-unique-prefix
                          "aa11000000000000000000000000000000000000000000000000000000000001"
                          '("aa11000000000000000000000000000000000000000000000000000000000001"
                            "bb22000000000000000000000000000000000000000000000000000000000002"))))
      ;; Two hashes sharing "aa" prefix need longer prefix
      (assert (let ((p (shortest-unique-prefix
                        "aa11000000000000000000000000000000000000000000000000000000000001"
                        '("aa11000000000000000000000000000000000000000000000000000000000001"
                          "aa22000000000000000000000000000000000000000000000000000000000002"))))
                (and (>= (string-length p) 4)
                     (string=? p (substring "aa11000000000000000000000000000000000000000000000000000000000001"
                                            0 (string-length p))))))

      ;; Test 2: disambiguation with duplicate names
      ;; Create store: two combiners both named "helper" (via mapping), one root "app"
      (let* ((temp-dir (format #f "/tmp/bb-test-print-~a" (random 1000000)))
             (hash-h1  "aa11000000000000000000000000000000000000000000000000000000000001")
             (hash-h2  "bb22000000000000000000000000000000000000000000000000000000000002")
             (hash-app "cc33000000000000000000000000000000000000000000000000000000000003"))
        (when (file-exists? temp-dir)
          (store-delete-directory! temp-dir))
        (mkdir temp-dir)
        (call-with-output-file (store-path-join temp-dir "config.scm")
          (lambda (p) (write '((remotes . ())) p)))
        (let ((dir-h1  (store-path-join temp-dir "combiners" hash-h1))
              (dir-h2  (store-path-join temp-dir "combiners" hash-h2))
              (dir-app (store-path-join temp-dir "combiners" hash-app)))
          (store-ensure-directory dir-h1)
          (store-ensure-directory dir-h2)
          (store-ensure-directory dir-app)
          ;; helper v1: (lambda (x) (+ x 1))
          (call-with-output-file (store-path-join dir-h1 "tree.scm")
            (lambda (p)
              (write '((body . ((mobius-primitive-ref 1)
                                (mobius-var 1)
                                ((mobius-primitive-ref 14) (mobius-var 1) 1)))) p)))
          ;; helper v2: (lambda (x) (+ x 2))
          (call-with-output-file (store-path-join dir-h2 "tree.scm")
            (lambda (p)
              (write '((body . ((mobius-primitive-ref 1)
                                (mobius-var 1)
                                ((mobius-primitive-ref 14) (mobius-var 1) 2)))) p)))
          ;; app: (lambda (x) (h1 (h2 x)))
          (call-with-output-file (store-path-join dir-app "tree.scm")
            (lambda (p)
              (write `((body . ((mobius-primitive-ref 1)
                                (mobius-var 1)
                                ((mobius-constant-ref ,hash-h1)
                                 ((mobius-constant-ref ,hash-h2) (mobius-var 1)))))) p)))
          ;; Mappings: both helpers named "helper"
          (let ((map-h1  (store-path-join dir-h1  "mappings" "00" "01"))
                (map-h2  (store-path-join dir-h2  "mappings" "00" "02"))
                (map-app (store-path-join dir-app "mappings" "00" "03")))
            (store-ensure-directory map-h1)
            (store-ensure-directory map-h2)
            (store-ensure-directory map-app)
            (call-with-output-file (store-path-join map-h1 "map.scm")
              (lambda (p) (write '((mapping (0 . "helper") (1 . "x"))) p)))
            (call-with-output-file (store-path-join map-h2 "map.scm")
              (lambda (p) (write '((mapping (0 . "helper") (1 . "x"))) p)))
            (call-with-output-file (store-path-join map-app "map.scm")
              (lambda (p) (write '((mapping (0 . "app") (1 . "x"))) p))))
          ;; Name-index: only latest "helper" registered
          (let ((name-index (list (cons "helper" hash-h2)
                                  (cons "app" hash-app))))
            (let ((port (open-output-string)))
              (parameterize ((current-output-port port)
                             (current-directory temp-dir))
                (command-print (list "app")))
              (let ((result (get-output-string port)))
                ;; Library structure
                (assert (string-contains? result "#!chezscheme"))
                (assert (string-contains? result "(export main)"))
                ;; Both helpers should have @hash disambiguation
                (assert (string-contains? result "helper@aa11"))
                (assert (string-contains? result "helper@bb22"))
                ;; Root combiner is main
                (assert (string-contains? result "define main"))
                ;; Body of main should reference disambiguated names
                (assert (string-contains? result "helper@aa11"))
                (assert (string-contains? result "helper@bb22"))))))
        (store-delete-directory! temp-dir))

      ;; Test 3: unique names — no @hash suffix
      (let* ((temp-dir (format #f "/tmp/bb-test-print-~a" (random 1000000)))
             (hash-add1 "aa11000000000000000000000000000000000000000000000000000000000001")
             (hash-dbl  "bb22000000000000000000000000000000000000000000000000000000000002"))
        (when (file-exists? temp-dir)
          (store-delete-directory! temp-dir))
        (mkdir temp-dir)
        (call-with-output-file (store-path-join temp-dir "config.scm")
          (lambda (p) (write '((remotes . ())) p)))
        (let ((dir-add1 (store-path-join temp-dir "combiners" hash-add1))
              (dir-dbl  (store-path-join temp-dir "combiners" hash-dbl)))
          (store-ensure-directory dir-add1)
          (store-ensure-directory dir-dbl)
          (call-with-output-file (store-path-join dir-add1 "tree.scm")
            (lambda (p)
              (write '((body . ((mobius-primitive-ref 1)
                                (mobius-var 1)
                                ((mobius-primitive-ref 14) (mobius-var 1) 1)))) p)))
          (call-with-output-file (store-path-join dir-dbl "tree.scm")
            (lambda (p)
              (write `((body . ((mobius-primitive-ref 1)
                                (mobius-var 1)
                                ((mobius-constant-ref ,hash-add1)
                                 ((mobius-constant-ref ,hash-add1) (mobius-var 1)))))) p)))
          (let ((map-add1 (store-path-join dir-add1 "mappings" "00" "01"))
                (map-dbl  (store-path-join dir-dbl  "mappings" "00" "02")))
            (store-ensure-directory map-add1)
            (store-ensure-directory map-dbl)
            (call-with-output-file (store-path-join map-add1 "map.scm")
              (lambda (p) (write '((mapping (0 . "add1") (1 . "x"))) p)))
            (call-with-output-file (store-path-join map-dbl "map.scm")
              (lambda (p) (write '((mapping (0 . "use-add1") (1 . "x"))) p))))
          (let ((name-index (list (cons "add1" hash-add1)
                                  (cons "use-add1" hash-dbl))))
            (let ((port (open-output-string)))
              (parameterize ((current-output-port port)
                             (current-directory temp-dir))
                (command-print (list "use-add1")))
              (let ((result (get-output-string port)))
                ;; No @ suffix since names are unique
                (assert (string-contains? result "define add1"))
                (assert (not (string-contains? result "@")))
                (assert (string-contains? result "define main"))))))
        (store-delete-directory! temp-dir))))

  (define ~check-cli-doc-roundtrip
    (lambda ()
      (let* ((temp (format #f "/tmp/bb-doc-roundtrip-~a" (random 1000000)))
             (body '((mobius-primitive-ref 1) ((mobius-bind 1)) (mobius-variable 1)))
             (serialized (scheme-write-value body))
             (hash (sha256-string serialized))
             (author "tester")
             (lang "en")
             (mapping (list (cons 0 "identity") (cons 1 "x"))))
        (mkdir temp)
        ;; Write minimal config.scm so store operations work
        (call-with-output-file (store-path-join temp "config.scm")
          (lambda (p)
            (display "((author ((email . \"\") (languages . (\"en\")) (name . \"tester\") (website . \"\"))) (remotes . ()))" p)))
        ;; Store combiner with initial doc
        (store-combiner! temp hash body)
        (store-mapping! temp hash lang mapping "old doc")
        (store-record-wip-lineage! temp hash author "add")
        ;; Verify initial doc loads
        (let ((map-data (store-load-preferred-mapping temp hash)))
          (assert (string=? "old doc" (cdr (assq 'doc map-data)))))
        ;; Simulate edit-save-flow: source with new doc comment + same define
        (let* ((source ";; new doc\n\n(define identity (lambda (x) x))\n")
               (name-index (store-build-name-index temp))
               (null-editor "true")
               (tmp-file (string-append temp "/edit.scm")))
          (call-with-output-file tmp-file (lambda (p) (display source p)))
          (edit-save-flow source temp name-index lang hash null-editor tmp-file))
        ;; The mapping with "new doc" should now be preferred (latest)
        (let ((map-data (store-load-preferred-mapping temp hash)))
          (assert (string=? "new doc" (cdr (assq 'doc map-data)))))
        ;; Old mapping must still exist (append-only)
        (let ((all-mappings (store-list-mappings temp hash)))
          (assert (>= (length all-mappings) 2))
          (assert (member "old doc"
                          (map (lambda (m) (cdr (assq 'doc (cdr m)))) all-mappings))))
        (store-delete-directory! temp))))

  )
