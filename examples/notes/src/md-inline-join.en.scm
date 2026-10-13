;; md-inline-join: inline-render every line of LINES and join the
;; results with single spaces (markdown soft-wrap semantics).
(define md-inline-join
  (lambda (lines)
    (if (pair? lines)
        (if (pair? (cdr lines))
            (xeno "string-append" (md-inline (car lines)) " " (md-inline-join (cdr lines)))
            (md-inline (car lines)))
        "")))
