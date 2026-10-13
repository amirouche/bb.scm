;; turtle-tokenize: turn turtle program text into a token list.
;; Whitespace (space, newline, tab, carriage return) separates tokens
;; and is skipped; "[" and "]" are single tokens of their own; a run
;; of digits makes a number token; any other run makes a word token.
;; Tokens are built via turtle-token-make so the shapes match the
;; frozen data shape: ("word" w), ("number" n), ("open"), ("close").
(define turtle-tokenize
  (lambda (text)
    (define text-length (xeno "string-length" text))
    (define char-at
      (lambda (index)
        (xeno "substring" text index (+ index 1))))
    (define whitespace?
      (lambda (char)
        (if (xeno "string=?" char " ")
            #true
            (if (xeno "string=?" char "\n")
                #true
                (if (xeno "string=?" char "\t")
                    #true
                    (xeno "string=?" char "\r"))))))
    (define digit?
      (lambda (char)
        (if (xeno "string=?" char "0")
            #true
            (if (xeno "string=?" char "1")
                #true
                (if (xeno "string=?" char "2")
                    #true
                    (if (xeno "string=?" char "3")
                        #true
                        (if (xeno "string=?" char "4")
                            #true
                            (if (xeno "string=?" char "5")
                                #true
                                (if (xeno "string=?" char "6")
                                    #true
                                    (if (xeno "string=?" char "7")
                                        #true
                                        (if (xeno "string=?" char "8")
                                            #true
                                            (xeno "string=?" char "9"))))))))))))
    (define digits-only?
      (lambda (start end)
        (if (= start end)
            #true
            (if (digit? (char-at start))
                (digits-only? (+ start 1) end)
                #false))))
    (define token-at
      (lambda (start end)
        (if (digits-only? start end)
            (turtle-token-make (xeno "string->number" (xeno "substring" text start end)))
            (turtle-token-make (xeno "substring" text start end)))))
    (define flush
      (lambda (start end tokens)
        (if (= start end)
            tokens
            (cons (token-at start end) tokens))))
    (define tokens-reverse
      (lambda (tokens acc)
        (if (eq? tokens #nil)
            acc
            (tokens-reverse (cdr tokens) (cons (car tokens) acc)))))
    (define scan
      (lambda (index start tokens)
        (if (= index text-length)
            (tokens-reverse (flush start index tokens) #nil)
            ((lambda (char)
               (if (whitespace? char)
                   (scan (+ index 1) (+ index 1) (flush start index tokens))
                   (if (if (xeno "string=?" char "[")
                           #true
                           (xeno "string=?" char "]"))
                       (scan (+ index 1)
                             (+ index 1)
                             (flush start index (cons (turtle-token-make char) tokens)))
                       (scan (+ index 1) start tokens))))
             (char-at index)))))
    (scan 0 0 #nil)))
