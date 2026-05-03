;; todos-render-list: map todos list to an HTML string by calling todos-render-item on each.
(define todos-render-list
  (lambda (tlist)
    (if (pair? tlist)
        (xeno "string-append" (todos-render-item (car tlist)) (todos-render-list (cdr tlist)))
        "")))
