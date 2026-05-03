;; render-toc-list: lang, list-of-posts -> concatenated <li>...</li> strings.
(define render-toc-list
  (lambda (lang posts)
    (if (pair? posts)
        (str-append (render-toc-entry lang (car posts))
                    (render-toc-list lang (cdr posts)))
        "")))
