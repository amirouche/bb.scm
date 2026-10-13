;; turtle-token-make: build one token from an atom. A number atom
;; makes a number token; "[" makes an open token; "]" makes a close
;; token; any other string makes a word token.
(define turtle-token-make
  (lambda (atom)
    (if (string? atom)
        (if (xeno "string=?" atom "[")
            (cons "open" #nil)
            (if (xeno "string=?" atom "]")
                (cons "close" #nil)
                (cons "word" (cons atom #nil))))
        (cons "number" (cons atom #nil)))))
