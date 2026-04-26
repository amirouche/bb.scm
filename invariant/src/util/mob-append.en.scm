;; mob-append: standard recursive list append over pairs/#nil.
(define mob-append
  (lambda (a b)
    (if (pair? a)
        (cons (car a) (mob-append (cdr a) b))
        b)))
