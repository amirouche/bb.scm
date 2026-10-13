;; ~check-turtle-tokenize: turtle-tokenize turns program text into
;; tokens. Whitespace separates tokens and is skipped; "[" and "]"
;; are tokens of their own; a run of digits makes a number token; any
;; other run makes a word token.
(define ~check-turtle-tokenize
  (lambda (turtle-tokenize)
    (assume (tree-equal?
             (turtle-tokenize "forward 100")
             (turtle-token-list (cons "forward" (cons 100 #nil))))
            "tokenize forward 100")
    (assume (tree-equal?
             (turtle-tokenize "repeat 2 [ forward 10 ]")
             (turtle-token-list (cons "repeat"
                                      (cons 2
                                            (cons "["
                                                  (cons "forward"
                                                        (cons 10
                                                              (cons "]" #nil))))))))
            "tokenize repeat brackets")
    (assume (tree-equal?
             (turtle-tokenize "penup")
             (turtle-token-list (cons "penup" #nil)))
            "tokenize penup")
    (assume (tree-equal?
             (turtle-tokenize "color red")
             (turtle-token-list (cons "color" (cons "red" #nil))))
            "tokenize color")
    (assume (tree-equal?
             (turtle-tokenize "forward  100
right 90")
             (turtle-token-list (cons "forward"
                                      (cons 100
                                            (cons "right" (cons 90 #nil))))))
            "tokenize skips repeated whitespace and newlines")))
