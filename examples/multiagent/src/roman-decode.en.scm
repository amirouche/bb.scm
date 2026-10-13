;; roman-decode: valid Roman numeral string -> integer.
(define roman-decode
  (lambda (s)
    (roman-decode-chars s 0 0)))
