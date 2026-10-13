;; tree-equal?: structural equality over nested trees of pairs,
;; strings, numbers, and nil. Pairs must match shape; numbers compare
;; with =; strings with string=?. Used by check combiners to compare
;; combiner output against expected values.
(define tree-equal?
  (lambda (left right)
    (if (pair? left)
        (if (pair? right)
            (if (tree-equal? (car left) (car right))
                (tree-equal? (cdr left) (cdr right))
                #false)
            #false)
        (if (pair? right)
            #false
            (if (eq? left #nil)
                (eq? right #nil)
                (if (string? left)
                    (if (string? right)
                        (xeno "string=?" left right)
                        #false)
                    (if (string? right)
                        #false
                        (= left right))))))))
