;; duration-parse: compact duration string -> seconds.
;; Units are d h m s; a bare number means seconds.
(define duration-parse
  (lambda (duration)
    (duration-chars-scan duration 0 0 0)))
