;; turtle-parse: token list -> command tree.
;;
;; A single stack walk over the flat token list, so no mutual
;; recursion is needed. The stack holds frames (count . parent-acc):
;; a "repeat" count followed by "[" pushes one and starts a fresh
;; accumulator; "]" pops it and splices ("repeat" n children)
;; into the parent accumulator. Unknown words, stray numbers and
;; brackets, and commands missing their argument parse to
;; ("error" word) values instead of raising; the walk consumes
;; exactly the offending token so the rest still parses.
(define
 turtle-parse
 (lambda
  (tokens)
  (define
   walk
   (lambda
    (tokens stack acc)
    (if
     (eq? tokens #nil)
     (if
      (eq? stack #nil)
      (xeno "reverse" acc)
      (walk
       #nil
       (cdr stack)
       (cons (cons "error" (cons "repeat" #nil)) (cdr (car stack)))))
     ((lambda
       (token rest)
       (if
        (xeno "string=?" (car token) "word")
        (if
         (xeno "string=?" (car (cdr token)) "penup")
         (walk rest stack (cons (cons "penup" #nil) acc))
         (if
          (xeno "string=?" (car (cdr token)) "pendown")
          (walk rest stack (cons (cons "pendown" #nil) acc))
          (if
           (xeno "string=?" (car (cdr token)) "color")
           (if
            (eq? rest #nil)
            (walk
             rest
             stack
             (cons (cons "error" (cons "color" #nil)) acc))
            (if
             (xeno "string=?" (car (car rest)) "word")
             (walk
              (cdr rest)
              stack
              (cons
               (cons "color" (cons (car (cdr (car rest))) #nil))
               acc))
             (walk
              rest
              stack
              (cons (cons "error" (cons "color" #nil)) acc))))
           (if
            (eq? rest #nil)
            (walk
             rest
             stack
             (cons (cons "error" (cons (car (cdr token)) #nil)) acc))
            (if
             (xeno "string=?" (car (car rest)) "number")
             ((lambda
               (argument tail)
               (if
                (xeno "string=?" (car (cdr token)) "repeat")
                (if
                 (eq? tail #nil)
                 (walk
                  rest
                  stack
                  (cons (cons "error" (cons "repeat" #nil)) acc))
                 (if
                  (xeno "string=?" (car (car tail)) "open")
                  (walk
                   (cdr tail)
                   (cons (cons argument acc) stack)
                   #nil)
                  (walk
                   rest
                   stack
                   (cons (cons "error" (cons "repeat" #nil)) acc))))
                (if
                 (xeno "string=?" (car (cdr token)) "forward")
                 (walk
                  tail
                  stack
                  (cons (cons "forward" (cons argument #nil)) acc))
                 (if
                  (xeno "string=?" (car (cdr token)) "backward")
                  (walk
                   tail
                   stack
                   (cons (cons "backward" (cons argument #nil)) acc))
                  (if
                   (xeno "string=?" (car (cdr token)) "left")
                   (walk
                    tail
                    stack
                    (cons (cons "left" (cons argument #nil)) acc))
                   (if
                    (xeno "string=?" (car (cdr token)) "right")
                    (walk
                     tail
                     stack
                     (cons (cons "right" (cons argument #nil)) acc))
                    (walk
                     rest
                     stack
                     (cons
                      (cons "error" (cons (car (cdr token)) #nil))
                      acc))))))))
              (car (cdr (car rest)))
              (cdr rest))
             (walk
              rest
              stack
              (cons (cons "error" (cons (car (cdr token)) #nil)) acc)))))))
        (if
         (xeno "string=?" (car token) "number")
         (walk
          rest
          stack
          (cons
           (cons
            "error"
            (cons (xeno "number->string" (car (cdr token))) #nil))
           acc))
         (if
          (xeno "string=?" (car token) "open")
          (walk rest stack (cons (cons "error" (cons "[" #nil)) acc))
          (if
           (eq? stack #nil)
           (walk rest stack (cons (cons "error" (cons "]" #nil)) acc))
           (walk
            rest
            (cdr stack)
            (cons
             (cons
              "repeat"
              (cons (car (car stack)) (cons (xeno "reverse" acc) #nil)))
             (cdr (car stack)))))))))
      (car tokens)
      (cdr tokens)))))
  (walk tokens #nil #nil)))
