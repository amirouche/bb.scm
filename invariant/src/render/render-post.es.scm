;; mostrar-relato: lang post enlace-anterior enlace-siguiente -> cadena <article>
(define mostrar-relato
  (lambda (lang post prev-link next-link)
    (str-concat
     (list-of "<article>\n"
              "<header><h2>" (escape-html (post-title post)) "</h2></header>\n"
              (render-paragraphs (post-paragraphs post))
              "<nav class=\"post\">"
              prev-link
              next-link
              "</nav>\n"
              "</article>\n"))))
