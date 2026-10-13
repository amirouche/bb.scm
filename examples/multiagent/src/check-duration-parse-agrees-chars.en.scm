;; ~check-duration-parse-agrees-chars: equivalence certificate — the
;; candidate computes the same values as agent-duration's tree
;; (duration-chars-scan) on the bounded domain 0..999 seconds, in both
;; formatted and bare-number form. Registered on the OTHER candidate.
(define ~check-duration-parse-agrees-chars
  (lambda (candidate)
    (~check-duration-parse-walk-chars candidate 0)))
