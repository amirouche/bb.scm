;; ensure-dir: path -> #void   (mkdir -p; idempotent)
(define ensure-dir
  (lambda (path)
    (xeno "system" (str-append "mkdir -p " path))))
