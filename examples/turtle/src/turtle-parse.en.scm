;; turtle-parse: turn a turtle token list into a command tree.
;; Tokens are ("word" w), ("number" n), ("open"), ("close").
;; Commands are ("forward" n), ("backward" n), ("left" n), ("right" n),
;; ("penup"), ("pendown"), ("color" name), ("repeat" n (children)),
;; and ("error" word). Unknown words, stray tokens, and commands
;; missing their argument become ("error" word) values; parsing never
;; raises. Nesting is solved inside this single combiner with a stack
;; walk over the flat token list: the parser state is a stack of frames
;; (repeat-count . reversed-commands), one frame per open bracket plus
;; the bottom frame, so no recursion across combiners is needed.
(define turtle-parse
  (lambda (tokens)
    (define turtle-parse-kind
      (lambda (token)
        (car token)))
    (define turtle-parse-value
      (lambda (token)
        (car (cdr token))))
    (define turtle-parse-number?
      (lambda (token)
        (xeno "string=?" (turtle-parse-kind token) "number")))
    (define turtle-parse-word?
      (lambda (token)
        (xeno "string=?" (turtle-parse-kind token) "word")))
    (define turtle-parse-open?
      (lambda (token)
        (xeno "string=?" (turtle-parse-kind token) "open")))
    (define turtle-parse-close?
      (lambda (token)
        (xeno "string=?" (turtle-parse-kind token) "close")))
    (define turtle-parse-command!
      ;; add a command to the top frame of the stack
      (lambda (stack command)
        (cons (cons (car (car stack))
                    (cons command (cdr (car stack))))
              (cdr stack))))
    (define turtle-parse-frame-close
      ;; complete the top repeat frame and attach it to its parent
      (lambda (stack)
        ((lambda (children)
           (cons (cons (car (car (cdr stack)))
                       (cons (cons "repeat"
                                   (cons (car (car stack))
                                         (cons children #nil)))
                             (cdr (car (cdr stack)))))
                 (cdr (cdr stack))))
         (xeno "reverse" (cdr (car stack))))))
    (define turtle-parse-stack-flush
      ;; at end of tokens, close any still-open repeat frame, then
      ;; return the bottom frame commands in source order
      (lambda (stack)
        (if (pair? (cdr stack))
            (turtle-parse-stack-flush (turtle-parse-frame-close stack))
            (xeno "reverse" (cdr (car stack))))))
    (define turtle-parse-number-command
      ;; forward, backward, left, right: consume a number argument or
      ;; emit an error; returns (remaining-tokens . stack)
      (lambda (stack name rest)
        (if (if (pair? rest)
                (turtle-parse-number? (car rest))
                #false)
            (cons (cdr rest)
                  (turtle-parse-command!
                   stack
                   (cons name (cons (turtle-parse-value (car rest)) #nil))))
            (cons rest
                  (turtle-parse-command!
                   stack
                   (cons "error" (cons name #nil)))))))
    (define turtle-parse-color-command
      ;; color: consume a word argument or emit an error;
      ;; returns (remaining-tokens . stack)
      (lambda (stack rest)
        (if (if (pair? rest)
                (turtle-parse-word? (car rest))
                #false)
            (cons (cdr rest)
                  (turtle-parse-command!
                   stack
                   (cons "color" (cons (turtle-parse-value (car rest)) #nil))))
            (cons rest
                  (turtle-parse-command!
                   stack
                   (cons "error" (cons "color" #nil)))))))
    (define turtle-parse-repeat-command
      ;; repeat n [ body ]: push a new frame, or emit an error;
      ;; returns (remaining-tokens . stack)
      (lambda (stack rest)
        (if (if (pair? rest)
                (turtle-parse-number? (car rest))
                #false)
            (if (if (pair? (cdr rest))
                    (turtle-parse-open? (car (cdr rest)))
                    #false)
                (cons (cdr (cdr rest))
                      (cons (cons (turtle-parse-value (car rest)) #nil)
                            stack))
                (cons rest
                      (turtle-parse-command!
                       stack
                       (cons "error" (cons "repeat" #nil)))))
            (cons rest
                  (turtle-parse-command!
                   stack
                   (cons "error" (cons "repeat" #nil)))))))
    (define turtle-parse-word-command
      ;; dispatch a word token to its command builder;
      ;; returns (remaining-tokens . stack)
      (lambda (stack word rest)
        (if (xeno "string=?" word "forward")
            (turtle-parse-number-command stack "forward" rest)
            (if (xeno "string=?" word "backward")
                (turtle-parse-number-command stack "backward" rest)
                (if (xeno "string=?" word "left")
                    (turtle-parse-number-command stack "left" rest)
                    (if (xeno "string=?" word "right")
                        (turtle-parse-number-command stack "right" rest)
                        (if (xeno "string=?" word "penup")
                            (cons rest
                                  (turtle-parse-command!
                                   stack
                                   (cons "penup" #nil)))
                            (if (xeno "string=?" word "pendown")
                                (cons rest
                                      (turtle-parse-command!
                                       stack
                                       (cons "pendown" #nil)))
                                (if (xeno "string=?" word "color")
                                    (turtle-parse-color-command stack rest)
                                    (if (xeno "string=?" word "repeat")
                                        (turtle-parse-repeat-command stack rest)
                                        (cons rest
                                              (turtle-parse-command!
                                               stack
                                               (cons "error"
                                                     (cons word #nil))))))))))))))
    (define turtle-parse-walk
      ;; fold the token list into the stack, one token at a time
      (lambda (tokens stack)
        (if (pair? tokens)
            (if (turtle-parse-word? (car tokens))
                ((lambda (step)
                   (turtle-parse-walk (car step) (cdr step)))
                 (turtle-parse-word-command
                  stack
                  (turtle-parse-value (car tokens))
                  (cdr tokens)))
                (if (turtle-parse-close? (car tokens))
                    (if (pair? (cdr stack))
                        (turtle-parse-walk (cdr tokens)
                                           (turtle-parse-frame-close stack))
                        (turtle-parse-walk
                         (cdr tokens)
                         (turtle-parse-command!
                          stack
                          (cons "error" (cons "]" #nil)))))
                    (if (turtle-parse-open? (car tokens))
                        (turtle-parse-walk
                         (cdr tokens)
                         (turtle-parse-command!
                          stack
                          (cons "error" (cons "[" #nil))))
                        (turtle-parse-walk
                         (cdr tokens)
                         (turtle-parse-command!
                          stack
                          (cons "error"
                                (cons (xeno "number->string"
                                            (turtle-parse-value (car tokens)))
                                      #nil)))))))
            (turtle-parse-stack-flush stack))))
    (turtle-parse-walk tokens (cons (cons #false #nil) #nil))))
