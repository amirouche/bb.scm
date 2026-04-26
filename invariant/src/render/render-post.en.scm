;; render-post: lang post prev-link next-link -> html article element string.
;; prev-link and next-link are pre-rendered <a> strings or "" for missing.
(define render-post
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
