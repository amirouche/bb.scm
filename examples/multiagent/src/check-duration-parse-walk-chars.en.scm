;; ~check-duration-parse-walk-chars: walk the bounded equivalence domain
;; comparing the candidate against agent-duration's implementation
;; (duration-chars-scan is its scanner). For each i in 0..999, both must
;; agree on the formatted duration and on the bare-number form.
(define ~check-duration-parse-walk-chars
  (lambda (candidate i)
    (if (< i 1000)
        (begin
          (assume (= (candidate (duration-format i))
                    (duration-chars-scan (duration-format i) 0 0 0))
                  "formatted domain")
          (assume (= (candidate (xeno "number->string" i))
                    (duration-chars-scan (xeno "number->string" i) 0 0 0))
                  "bare number domain")
          (~check-duration-parse-walk-chars candidate (+ i 1)))
        #true)))
