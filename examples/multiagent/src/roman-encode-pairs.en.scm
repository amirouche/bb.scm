;; roman-encode-pairs: greedy-encode integer N against the descending
;; pairs table PAIRS (each entry is a (value . numeral-string) pair),
;; appending numeral strings onto the accumulator ACC.
;; Call as (roman-encode-pairs N PAIRS "").
(define roman-encode-pairs
  (lambda (n pairs acc)
    (if (pair? pairs)
        (if (or (= (car (car pairs)) n) (< (car (car pairs)) n))
            (roman-encode-pairs (- n (car (car pairs)))
                                pairs
                                (xeno "string-append" acc (cdr (car pairs))))
            (roman-encode-pairs n (cdr pairs) acc))
        acc)))
