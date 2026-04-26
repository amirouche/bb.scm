;; write-file: path string -> #void
;; The only place in the project (besides ensure-dir) where xeno is used.
;; Imperative open/put/close — Phase 0a confirmed this pattern works.
;; rm -f beforehand for replace semantics.
(define write-file
  (lambda (path contents)
    (begin
      (xeno "system" (str-append "rm -f " path))
      (define port (xeno "open-output-file" path))
      (xeno "put-string" port contents)
      (xeno "close-output-port" port))))
