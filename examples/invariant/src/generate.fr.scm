;; engendrer : lang -> #void  (mapping FR de `generate`)
(define engendrer
  (lambda (lang)
    (begin
      (ensure-dir (str-append "out/" lang))
      (define posts (manifest lang))
      (generate-posts lang posts)
      (generate-index lang posts)
      (write-file "out/style.css" (style-css)))))
