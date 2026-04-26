;; generate: lang -> #void
;; Builds out/<lang>/* and rewrites out/style.css idempotently.
(define generate
  (lambda (lang)
    (begin
      (ensure-dir (str-append "out/" lang))
      (define posts (manifest lang))
      (generate-posts lang posts)
      (generate-index lang posts)
      (write-file "out/style.css" (style-css)))))
