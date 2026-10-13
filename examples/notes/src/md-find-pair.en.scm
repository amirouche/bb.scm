;; md-find-pair: first index >= FROM where the character with code CODE
;; appears twice in a row, or (string-length S).
(define md-find-pair
  (lambda (s code from)
    (define n (xeno "string-length" s))
    (if (< (+ from 1) n)
        (if (and (= (char->integer (xeno "string-ref" s from)) code)
                 (= (char->integer (xeno "string-ref" s (+ from 1))) code))
            from
            (md-find-pair s code (+ from 1)))
        n)))
