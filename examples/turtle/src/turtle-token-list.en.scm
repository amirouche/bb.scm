;; turtle-token-list: build a token list from a flat list of atoms,
;; via turtle-token-make. Lets check combiners write token fixtures
;; without depending on turtle-tokenize.
(define turtle-token-list
  (lambda (atoms)
    (if (eq? atoms #nil)
        #nil
        (cons (turtle-token-make (car atoms))
              (turtle-token-list (cdr atoms))))))
