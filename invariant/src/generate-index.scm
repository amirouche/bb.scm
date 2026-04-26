;; generate-index: lang, posts -> #void  (writes out/<lang>/index.html)
(define generate-index
  (lambda (lang posts)
    (begin
      (define inner (render-index lang posts))
      (define page (render-page lang inner))
      (define path (str-concat (list-of "out/" lang "/index.html")))
      (write-file path page))))
