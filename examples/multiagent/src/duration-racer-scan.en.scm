;; duration-racer-scan: fold the characters of S from INDEX into seconds.
;; NUMBER is the value of the digits accumulated since the last unit
;; character, TOTAL the seconds folded so far. Unit characters are
;; d (100) day, h (104) hour, m (109) minute, s (115) second; anything
;; else that is not an ASCII digit is rejected.
(define duration-racer-scan
  (lambda (s index number total)
    (define n (xeno "string-length" s))
    (define code
      (if (< index n)
          (char->integer (xeno "string-ref" s index))
          0))
    (define digit
      (if (< code 48)
          #false
          (if (> code 57) #false #true)))
    (define unit-seconds
      (if (= code 100)
          86400
          (if (= code 104)
              3600
              (if (= code 109) 60 (if (= code 115) 1 0)))))
    (if (= index n)
        (+ total number)
        (if digit
            (duration-racer-scan
              s (+ index 1) (+ (* number 10) (- code 48)) total)
            (begin
              (assume (> unit-seconds 0)
                      "duration-racer-scan: unknown unit character")
              (duration-racer-scan
                s (+ index 1) 0 (+ total (* number unit-seconds))))))))
