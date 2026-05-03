#!chezscheme
(library (bb server)

  (export server-start!)

  (import (chezscheme)
          (transparenturing)
          (bb values)
          (bb store)
          (bb evaluator)
          (bb base-library))

  ;; Join path segments with "/".
  (define %path-join
    (lambda (segments)
      (if (null? segments) ""
          (let loop ((rest (cdr segments)) (acc (car segments)))
            (if (null? rest) acc
                (loop (cdr rest) (string-append acc "/" (car rest))))))))

  ;; Return the directory part of a file path.
  (define %path-dirname
    (lambda (path)
      (let loop ((i (- (string-length path) 1)))
        (cond
          ((< i 0) ".")
          ((char=? (string-ref path i) #\/)
           (if (= i 0) "/" (substring path 0 i)))
          (else (loop (- i 1)))))))

  ;; Recursively list non-.wip.scm files under dir,
  ;; returning paths relative to base-dir.
  (define %enumerate-files
    (lambda (base-dir dir)
      (apply append
             (map (lambda (entry)
                    (let ((full (store-path-join dir entry)))
                      (cond
                        ((file-directory? full)
                         (%enumerate-files base-dir full))
                        ((store-string-suffix? ".wip.scm" entry) '())
                        (else
                         (list (substring full
                                          (+ (string-length base-dir) 1)
                                          (string-length full)))))))
                  (directory-list dir)))))

  ;; Check Authorization: Bearer header.
  (define %authorized?
    (lambda (headers api-key)
      (or (not api-key)
          (let ((auth (assq 'authorization headers)))
            (and auth
                 (string=? (cdr auth)
                            (string-append "Bearer " api-key)))))))

  ;; Build hash→name lookup closure from name-index.
  (define %make-hash->name
    (lambda (name-index root)
      (lambda (hash)
        (let loop ((remaining name-index))
          (if (null? remaining)
              (guard (exn (#t #f))
                (let* ((map-data (store-load-first-mapping root hash))
                       (mapping (cdr (assq 'mapping map-data)))
                       (entry (assv 0 mapping)))
                  (and entry (string->symbol (cdr entry)))))
              (if (string=? hash (cdar remaining))
                  (string->symbol (caar remaining))
                  (loop (cdr remaining))))))))

  ;; Load all combiners from name-index into environment.
  (define %load-env
    (lambda (name-index root env)
      (let ((hash->name (%make-hash->name name-index root)))
        (let ((env (let loop ((remaining name-index) (e env))
                     (if (null? remaining) e
                         (loop (cdr remaining)
                               (name-environment-extend
                                 e (string->symbol (caar remaining)) mobius-void))))))
          (for-each
            (lambda (entry)
              (guard (exn (#t (void)))
                (let* ((name (string->symbol (car entry)))
                       (hash (cdr entry))
                       (body (store-load-combiner root hash))
                       (map-data (store-load-preferred-mapping root hash))
                       (mapping (cdr (assq 'mapping map-data)))
                       ;; When the name for this hash is qualified (collision), update the
                       ;; self-name entry (index 0) so recursive calls use the qualified name
                       (mapping (let ((qualified-self (hash->name hash)))
                                  (if (and qualified-self
                                           (let ((entry (assv 0 mapping)))
                                             (and entry
                                                  (not (string=? (symbol->string qualified-self)
                                                                 (cdr entry))))))
                                      (cons (cons 0 (symbol->string qualified-self))
                                            (filter (lambda (e) (not (= (car e) 0))) mapping))
                                      mapping)))
                       (surface (denormalize-tree body mapping hash->name))
                       (value (mobius-eval surface env))
                       (value (if (and (mobius-user-combiner? value)
                                       (not (mobius-combiner-name value)))
                                  (make-mobius-combiner
                                    (mobius-combiner-clauses value)
                                    (mobius-combiner-environment value)
                                    name)
                                  value)))
                  (name-environment-set! env name value))))
            name-index)
          env))))

  ;; Load a single combiner by hash from the store, evaluated in env.
  (define %load-by-hash
    (lambda (store-root hash env hash->name)
      (let* ((body     (store-load-combiner store-root hash))
             (map-data (guard (exn (#t #f))
                         (store-load-preferred-mapping store-root hash)))
             (mapping  (if map-data (cdr (assq 'mapping map-data)) '()))
             (surface  (denormalize-tree body mapping hash->name)))
        (mobius-eval surface env))))

  ;; Invoke handler combiner with (app-state req) argument tree.
  ;; req is an alist: "method" is a symbol (GET/POST/...), others are strings.
  (define %invoke-handler
    (lambda (app env handler method path params body)
      (let* ((req `(("method" . ,method)
                    ("path"   . ,(%path-join (map (lambda (s) (string-append "/" s)) path)))
                    ("params" . ,params)
                    ("body"   . ,(if (and (bytevector? body) (> (bytevector-length body) 0))
                                     (utf8->string body) ""))))
             (result (guard (ex (#t #f))
                       (mobius-apply handler (cons app (cons req mobius-nil)) env))))
        (if (not result)
            (values 500 (cons (string->utf8 "handler error") "text/plain") '())
            (let* ((lookup  (lambda (key) (or (assoc key result)
                                              (assq (string->symbol key) result))))
                   (s       (lookup "status"))
                   (status  (if s (cdr s) 200))
                   (b       (lookup "body"))
                   (body    (string->utf8
                               (if b (if (string? (cdr b)) (cdr b)
                                         (format #f "~s" (cdr b)))
                                   "")))
                   (h       (lookup "headers"))
                   (hdrs    (if h (cdr h) '()))
                   (ct-pair (assoc "content-type" hdrs))
                   (ct      (if ct-pair (cdr ct-pair) "text/html; charset=utf-8"))
                   (hdrs    (map (lambda (hdr)
                                   (cons (if (string? (car hdr))
                                             (string->symbol (car hdr))
                                             (car hdr))
                                         (cdr hdr)))
                                 (filter (lambda (hdr)
                                           (not (equal? (car hdr) "content-type")))
                                         hdrs))))
              (values status (cons body ct) hdrs))))))

  ;; Route an incoming HTTP request.
  (define %dispatch
    (lambda (store-root api-key app env hnd-comb _req method path params _parsed-body body headers)
      (cond
        ;; GET /api/store/index
        ((and (eq? method 'GET) (equal? path '("api" "store" "index")))
         (let* ((hashes (store-list-all-stored-hashes store-root))
                (text (apply string-append (map (lambda (h) (string-append h "\n")) hashes))))
           (values 200 (cons (string->utf8 text) "text/plain") '())))

        ;; GET /api/store/combiners/{hash}/files
        ((and (eq? method 'GET)
              (= (length path) 5)
              (equal? (list-head path 3) '("api" "store" "combiners"))
              (string=? (list-ref path 4) "files"))
         (let* ((hash (list-ref path 3))
                (cdir (store-combiner-directory store-root hash)))
           (if (not (file-exists? cdir))
               (values 404 (cons (string->utf8 "not found") "text/plain") '())
               (let ((listing (apply string-append
                                     (map (lambda (f) (string-append f "\n"))
                                          (%enumerate-files cdir cdir)))))
                 (values 200 (cons (string->utf8 listing) "text/plain") '())))))

        ;; GET /api/store/combiners/{hash}/{relpath...}
        ((and (eq? method 'GET)
              (>= (length path) 5)
              (equal? (list-head path 3) '("api" "store" "combiners")))
         (let* ((hash (list-ref path 3))
                (fp (apply store-path-join
                           (cons (store-combiner-directory store-root hash)
                                 (list-tail path 4)))))
           (if (and (file-exists? fp) (not (file-directory? fp)))
               (let ((content (call-with-port (open-file-input-port fp) get-bytevector-all)))
                 (values 200 (cons content "application/octet-stream") '()))
               (values 404 (cons (string->utf8 "not found") "text/plain") '()))))

        ;; PUT /api/store/combiners/{hash}/{relpath...}
        ((and (eq? method 'PUT)
              (>= (length path) 5)
              (equal? (list-head path 3) '("api" "store" "combiners")))
         (if (not (%authorized? headers api-key))
             (values 401 (cons (string->utf8 "unauthorized") "text/plain") '())
             (let* ((hash (list-ref path 3))
                    (rel (%path-join (list-tail path 4)))
                    (fp (apply store-path-join
                               (cons (store-combiner-directory store-root hash)
                                     (list-tail path 4)))))
               (if (store-string-suffix? ".wip.scm" rel)
                   (values 400 (cons (string->utf8 "wip files not accepted") "text/plain") '())
                   (begin
                     (store-ensure-directory (%path-dirname fp))
                     (call-with-port
                       (open-file-output-port fp (file-options replace) (buffer-mode block))
                       (lambda (p) (put-bytevector p (if (bytevector? body) body (bytevector)))))
                     (values 201 (cons (string->utf8 "created") "text/plain") '()))))))

        ;; All other requests → Mobius handler combiner at /
        (else
         (%invoke-handler app env hnd-comb method path params body)))))

  ;; Start the Mobius HTTP server.
  ;; app-hash:     hash of the application-state combiner (called once, no args)
  ;; handler-hash: hash of the request handler combiner (called per request with (state req))
  (define server-start!
    (lambda (store-root port api-key app-hash handler-hash)
      (let* ((idx      (store-build-name-index store-root))
             (env      (%load-env idx store-root
                          (install-base-library (make-initial-environment))))
             (h->name  (%make-hash->name idx store-root))
             (app-comb (%load-by-hash store-root app-hash env h->name))
             (hnd-comb (%load-by-hash store-root handler-hash env h->name)))
        (transparent
          port
          (lambda () (mobius-apply app-comb mobius-nil env))
          (lambda (app _client _extra) app)
          (lambda (app req method path params parsed-body body headers)
            (%dispatch store-root api-key app env hnd-comb
                       req method path params parsed-body body headers))))))

)
