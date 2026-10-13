;; ~check-duration-parse-agrees-racer: equivalence certificate — the
;; candidate computes the same values as agent-racer's tree
;; (duration-racer-scan) on the bounded domain 0..999 seconds, in both
;; formatted and bare-number form. Registered on the OTHER candidate.
(define ~check-duration-parse-agrees-racer
  (lambda (candidate)
    (~check-duration-parse-walk-racer candidate 0)))
