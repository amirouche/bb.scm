;; duration-chars-scan: walk DURATION from INDEX, accumulating NUMBER
;; (the digits read since the last unit character) and TOTAL seconds.
;; A unit character flushes NUMBER into TOTAL scaled by its factor;
;; the end of the string adds a bare NUMBER as seconds.
;; Character codes: 48-57 digits, 100 d, 104 h, 109 m, 115 s.
(define duration-chars-scan
  (lambda (duration index number total)
    (define size (xeno "string-length" duration))
    (define code
      (if (< index size)
          (char->integer (xeno "string-ref" duration index))
          0))
    (if (< index size)
        (if (= code 100)
            (duration-chars-scan duration (+ index 1) 0 (+ total (* number 86400)))
            (if (= code 104)
                (duration-chars-scan duration (+ index 1) 0 (+ total (* number 3600)))
                (if (= code 109)
                    (duration-chars-scan duration (+ index 1) 0 (+ total (* number 60)))
                    (if (= code 115)
                        (duration-chars-scan duration (+ index 1) 0 (+ total number))
                        (if (> code 47)
                            (if (< code 58)
                                (duration-chars-scan
                                 duration
                                 (+ index 1)
                                 (+ (* number 10) (- code 48))
                                 total)
                                (assume #false "duration-chars-scan: bad character"))
                            (assume #false "duration-chars-scan: bad character"))))))
        (+ total number))))
