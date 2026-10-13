;; ~check-duration-parse: duration-parse reads compact durations.
;; "1h30m" → 5400. A bare number means seconds.
(define ~check-duration-parse
  (lambda (duration-parse)
    (assume (= 5400 (duration-parse "1h30m")) "duration-parse 1h30m")
    (assume (= 172800 (duration-parse "2d")) "duration-parse 2d")
    (assume (= 90 (duration-parse "90s")) "duration-parse 90s")
    (assume (= 93784 (duration-parse "1d2h3m4s")) "duration-parse 1d2h3m4s")
    (assume (= 45 (duration-parse "45")) "duration-parse 45")
    (assume (= 0 (duration-parse "0")) "duration-parse 0")
    (assume (= 3600 (duration-parse "1h")) "duration-parse 1h")))
