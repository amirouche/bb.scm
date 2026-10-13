;; ~check-turtle-run: turtle-run walks a command tree from state
;; (0 0 0 pen-down black) — x, y, heading in degrees (0 = north,
;; clockwise), pen, color — and emits ("segment" x1 y1 x2 y2 color)
;; for every pen-down move. Error commands are skipped, not raised.
;; Comparisons go through turtle-round-tree so trigonometric epsilon
;; noise cannot fail an assert.
(define ~check-turtle-run
  (lambda (turtle-run)
    (assume (tree-equal?
             (turtle-round-tree
              (turtle-run (cons (cons "repeat"
                                      (cons 4
                                            (cons (cons (cons "forward" (cons 100 #nil))
                                                        (cons (cons "right" (cons 90 #nil)) #nil))
                                                  #nil)))
                                  #nil)))
             (turtle-round-tree
              (cons (cons "segment" (cons 0 (cons 0 (cons 0 (cons 100 (cons "black" #nil))))))
                    (cons (cons "segment" (cons 0 (cons 100 (cons 100 (cons 100 (cons "black" #nil))))))
                          (cons (cons "segment" (cons 100 (cons 100 (cons 100 (cons 0 (cons "black" #nil))))))
                                (cons (cons "segment" (cons 100 (cons 0 (cons 0 (cons 0 (cons "black" #nil))))))
                                      #nil))))))
            "run square")
    (assume (tree-equal?
             (turtle-round-tree
              (turtle-run (cons (cons "forward" (cons 50 #nil))
                                (cons (cons "penup" #nil)
                                      (cons (cons "forward" (cons 50 #nil)) #nil)))))
             (turtle-round-tree
              (cons (cons "segment" (cons 0 (cons 0 (cons 0 (cons 50 (cons "black" #nil))))))
                    #nil)))
            "run penup emits nothing")
    (assume (tree-equal?
             (turtle-round-tree
              (turtle-run (cons (cons "color" (cons "red" #nil))
                                (cons (cons "forward" (cons 100 #nil)) #nil))))
             (turtle-round-tree
              (cons (cons "segment" (cons 0 (cons 0 (cons 0 (cons 100 (cons "red" #nil))))))
                    #nil)))
            "run color carries to segment")
    (assume (tree-equal?
             (turtle-round-tree
              (turtle-run (cons (cons "left" (cons 90 #nil))
                                (cons (cons "forward" (cons 100 #nil)) #nil))))
             (turtle-round-tree
              (cons (cons "segment" (cons 0 (cons 0 (cons -100 (cons 0 (cons "black" #nil))))))
                    #nil)))
            "run left 90 goes west")
    (assume (tree-equal?
             (turtle-round-tree
              (turtle-run (cons (cons "backward" (cons 50 #nil))
                                (cons (cons "error" (cons "spiral" #nil))
                                      (cons (cons "forward" (cons 10 #nil)) #nil)))))
             (turtle-round-tree
              (cons (cons "segment" (cons 0 (cons 0 (cons 0 (cons -50 (cons "black" #nil))))))
                    (cons (cons "segment" (cons 0 (cons -50 (cons 0 (cons -40 (cons "black" #nil))))))
                          #nil))))
            "run skips error commands")))
