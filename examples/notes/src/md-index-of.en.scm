;; md-index-of: first index >= FROM where the character of S has code
;; CODE, or (string-length S) when there is none.
;; Character codes: 10 newline, 13 return, 38 &, 61 =, 40 (, 41 ),
;; 42 *, 91 [, 93 ], 96 `.
(define md-index-of
  (lambda (s code from)
    (define n (xeno "string-length" s))
    (if (< from n)
        (if (= (char->integer (xeno "string-ref" s from)) code)
            from
            (md-index-of s code (+ from 1)))
        n)))
