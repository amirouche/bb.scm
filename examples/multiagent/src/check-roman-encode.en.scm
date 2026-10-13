;; ~check-roman-encode: roman-encode renders known roman numerals.
;; The check receives the combiner under test as its argument.
(define ~check-roman-encode
  (lambda (roman-encode)
    (assume (xeno "string=?" "I" (roman-encode 1)) "roman-encode 1")
    (assume (xeno "string=?" "IV" (roman-encode 4)) "roman-encode 4")
    (assume (xeno "string=?" "IX" (roman-encode 9)) "roman-encode 9")
    (assume (xeno "string=?" "XIV" (roman-encode 14)) "roman-encode 14")
    (assume (xeno "string=?" "XL" (roman-encode 40)) "roman-encode 40")
    (assume (xeno "string=?" "XC" (roman-encode 90)) "roman-encode 90")
    (assume (xeno "string=?" "CD" (roman-encode 400)) "roman-encode 400")
    (assume (xeno "string=?" "CMXLIV" (roman-encode 944)) "roman-encode 944")
    (assume (xeno "string=?" "MCMXCIV" (roman-encode 1994)) "roman-encode 1994")
    (assume (xeno "string=?" "MMXXIV" (roman-encode 2024)) "roman-encode 2024")
    (assume (xeno "string=?" "MMMCMXCIX" (roman-encode 3999)) "roman-encode 3999")))
