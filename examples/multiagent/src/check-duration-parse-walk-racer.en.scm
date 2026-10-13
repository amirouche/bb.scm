;; ~check-duration-parse-walk-racer: walk the bounded equivalence domain
;; comparing the candidate against agent-racer's implementation
;; (duration-racer-scan is its scanner). For each i in 0..999, both must
;; agree on the formatted duration and on the bare-number form.
(define ~check-duration-parse-walk-racer
  (lambda (candidate i)
    (if (< i 1000)
        (begin
          (assume (= (candidate (duration-format i))
                    (duration-racer-scan (duration-format i) 0 0 0))
                  "formatted domain")
          (assume (= (candidate (xeno "number->string" i))
                    (duration-racer-scan (xeno "number->string" i) 0 0 0))
                  "bare number domain")
          (~check-duration-parse-walk-racer candidate (+ i 1)))
        #true)))
