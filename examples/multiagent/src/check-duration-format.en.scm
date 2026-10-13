;; ~check-duration-format: duration-format renders canonical durations.
;; Largest unit first, zero components omitted, bare seconds get "s".
(define ~check-duration-format
  (lambda (duration-format)
    (assume (xeno "string=?" "1h30m" (duration-format 5400)) "duration-format 5400")
    (assume (xeno "string=?" "2d" (duration-format 172800)) "duration-format 172800")
    (assume (xeno "string=?" "1m30s" (duration-format 90)) "duration-format 90")
    (assume (xeno "string=?" "1d2h3m4s" (duration-format 93784)) "duration-format 93784")
    (assume (xeno "string=?" "45s" (duration-format 45)) "duration-format 45")
    (assume (xeno "string=?" "0s" (duration-format 0)) "duration-format 0")))
