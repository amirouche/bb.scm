;; afficher-recit : lang post lien-precedent lien-suivant -> chaîne <article>
(define afficher-recit
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
