;; ~check-duration-roundtrip: duration-parse and duration-format agree.
;; The check receives the duration-parse candidate as its argument;
;; duration-format is resolved from the store at check time.
(define ~check-duration-roundtrip
  (lambda (duration-parse)
    (assume (= 5400 (duration-parse (duration-format 5400))) "roundtrip 5400")
    (assume (= 93784 (duration-parse (duration-format 93784))) "roundtrip 93784")
    (assume (= 90 (duration-parse (duration-format 90))) "roundtrip 90")
    (assume (= 45 (duration-parse (duration-format 45))) "roundtrip 45")))
