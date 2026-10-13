;; turtle-round-tree: scale every number in a tree by 1000 and round
;; it, so trigonometric epsilon noise disappears under tree-equal?.
;; Strings, nil, and booleans pass through unchanged.
(define turtle-round-tree
  (lambda (tree)
    (if (pair? tree)
        (cons (turtle-round-tree (car tree)) (turtle-round-tree (cdr tree)))
        (if (string? tree)
            tree
            (if (integer? tree)
                (xeno "round" (* 1000 tree))
                (if (float? tree)
                    (xeno "round" (* 1000 tree))
                    tree))))))
