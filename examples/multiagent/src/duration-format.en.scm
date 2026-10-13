;; duration-format: seconds -> canonical duration string.
;; Largest unit first, zero components omitted, bare seconds get "s".
(define duration-format
  (lambda (seconds)
    (define days (xeno "quotient" seconds 86400))
    (define hours (xeno "quotient" (xeno "remainder" seconds 86400) 3600))
    (define minutes (xeno "quotient" (xeno "remainder" seconds 3600) 60))
    (define rest (xeno "remainder" seconds 60))
    (define prefix
      (xeno "string-append"
        (if (> days 0)
            (xeno "string-append" (xeno "number->string" days) "d")
            "")
        (if (> hours 0)
            (xeno "string-append" (xeno "number->string" hours) "h")
            "")
        (if (> minutes 0)
            (xeno "string-append" (xeno "number->string" minutes) "m")
            "")))
    (if (or (> rest 0) (= (xeno "string-length" prefix) 0))
        (xeno "string-append" prefix (xeno "number->string" rest) "s")
        prefix)))
