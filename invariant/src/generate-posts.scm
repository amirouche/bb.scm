;; generate-posts: lang, list-of-posts -> #void
;; Iterates posts; for each, render-page over render-post and write-file.
;; prev/next nav is empty for the thin-slice; can be added later.
(define generate-posts
  (lambda (lang posts)
    (if (pair? posts)
        (begin
          (define post (car posts))
          (define inner (render-post lang post "" ""))
          (define page (render-page lang inner))
          (define path (str-concat
                        (list-of "out/" lang "/" (post-slug post) ".html")))
          (write-file path page)
          (generate-posts lang (cdr posts)))
        #void)))
