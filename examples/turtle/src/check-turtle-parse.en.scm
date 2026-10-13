;; ~check-turtle-parse: turtle-parse turns a token list into a
;; command tree. Commands are ("forward" n), ("backward" n),
;; ("left" n), ("right" n), ("penup"), ("pendown"), ("color" name);
;; repeat takes a count and a nested body ("repeat" n (children)).
;; Unknown words and missing arguments become ("error" word)
;; commands instead of raising.
(define ~check-turtle-parse
  (lambda (turtle-parse)
    (assume (tree-equal?
             (turtle-parse (turtle-token-list (cons "forward" (cons 100 #nil))))
             (cons (cons "forward" (cons 100 #nil)) #nil))
            "parse forward")
    (assume (tree-equal?
             (turtle-parse
              (turtle-token-list
               (cons "repeat"
                     (cons 2
                           (cons "["
                                 (cons "forward"
                                       (cons 10
                                             (cons "penup"
                                                   (cons "]" #nil)))))))))
             (cons (cons "repeat"
                         (cons 2
                               (cons (cons (cons "forward" (cons 10 #nil))
                                           (cons (cons "penup" #nil) #nil))
                                     #nil)))
                   #nil))
            "parse repeat body")
    (assume (tree-equal?
             (turtle-parse
              (turtle-token-list
               (cons "repeat"
                     (cons 2
                           (cons "["
                                 (cons "repeat"
                                       (cons 3
                                             (cons "["
                                                   (cons "forward"
                                                         (cons 10
                                                               (cons "]"
                                                                     (cons "right"
                                                                           (cons 90
                                                                                 (cons "]" #nil))))))))))))))
             (cons (cons "repeat"
                         (cons 2
                               (cons (cons (cons "repeat"
                                                 (cons 3
                                                       (cons (cons (cons "forward"
                                                                         (cons 10 #nil))
                                                                   #nil)
                                                             #nil)))
                                     (cons (cons "right" (cons 90 #nil)) #nil))
                                     #nil)))
                   #nil))
            "parse nested repeat")
    (assume (tree-equal?
             (turtle-parse (turtle-token-list (cons "color" (cons "red" #nil))))
             (cons (cons "color" (cons "red" #nil)) #nil))
            "parse color")
    (assume (tree-equal?
             (turtle-parse (turtle-token-list (cons "spiral" #nil)))
             (cons (cons "error" (cons "spiral" #nil)) #nil))
            "parse unknown word is an error value")
    (assume (tree-equal?
             (turtle-parse (turtle-token-list (cons "forward" #nil)))
             (cons (cons "error" (cons "forward" #nil)) #nil))
            "parse missing number is an error value")))
