;; roman-decode-chars: fold the Roman numeral string S from index I,
;; adding character values onto the accumulator TOTAL. A smaller value
;; immediately before a larger one folds as a difference (subtractive
;; pair). Call as (roman-decode-chars S 0 0).
(define roman-decode-chars
  (lambda (s i total)
    (define n (xeno "string-length" s))
    (if (< i n)
        (if (< (+ i 1) n)
            (if (< (roman-char-value (xeno "string-ref" s i))
                   (roman-char-value (xeno "string-ref" s (+ i 1))))
                (roman-decode-chars
                  s
                  (+ i 2)
                  (+ total
                     (- (roman-char-value (xeno "string-ref" s (+ i 1)))
                        (roman-char-value (xeno "string-ref" s i)))))
                (roman-decode-chars
                  s
                  (+ i 1)
                  (+ total (roman-char-value (xeno "string-ref" s i)))))
            (roman-decode-chars
              s
              (+ i 1)
              (+ total (roman-char-value (xeno "string-ref" s i)))))
        total)))
