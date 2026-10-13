;; ~check-turtle-bounds: turtle-bounds returns (min-x min-y max-x
;; max-y) over every endpoint of every segment. No segments yields
;; (0 0 0 0).
(define ~check-turtle-bounds
  (lambda (turtle-bounds)
    (assume (tree-equal?
             (turtle-round-tree
              (turtle-bounds (cons (cons "segment"
                                         (cons 0
                                               (cons 0
                                                     (cons 100
                                                           (cons 50
                                                                 (cons "black" #nil))))))
                                    (cons (cons "segment"
                                                (cons 20
                                                      (cons 10
                                                            (cons 30
                                                                  (cons 200
                                                                        (cons "red" #nil))))))
                                          #nil))))
             (turtle-round-tree (cons 0 (cons 0 (cons 100 (cons 200 #nil))))))
            "bounds over two segments")
    (assume (tree-equal?
             (turtle-round-tree (turtle-bounds #nil))
             (turtle-round-tree (cons 0 (cons 0 (cons 0 (cons 0 #nil))))))
            "bounds of nothing is zero")))
