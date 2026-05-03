(define mostrar-indice
  (lambda (lang posts)
    (str-concat
     (list-of
      "<section>\n"
      "<ol class=\"toc\">\n"
      (render-toc-list lang posts)
      "</ol>\n"
      "</section>\n"))))
