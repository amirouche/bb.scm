;; engendrar: lang -> #void  (mapeo ES de `generate`)
(define engendrar
  (lambda (lang)
    (begin
      (ensure-dir (str-append "out/" lang))
      (define posts (manifest lang))
      (generate-posts lang posts)
      (generate-index lang posts)
      (write-file "out/style.css" (style-css)))))
