;; ~check-roman-decode: roman-decode reads known roman numerals.
(define ~check-roman-decode
  (lambda (roman-decode)
    (assume (= 1 (roman-decode "I")) "roman-decode I")
    (assume (= 4 (roman-decode "IV")) "roman-decode IV")
    (assume (= 9 (roman-decode "IX")) "roman-decode IX")
    (assume (= 40 (roman-decode "XL")) "roman-decode XL")
    (assume (= 90 (roman-decode "XC")) "roman-decode XC")
    (assume (= 400 (roman-decode "CD")) "roman-decode CD")
    (assume (= 900 (roman-decode "CM")) "roman-decode CM")
    (assume (= 1994 (roman-decode "MCMXCIV")) "roman-decode MCMXCIV")
    (assume (= 2024 (roman-decode "MMXXIV")) "roman-decode MMXXIV")
    (assume (= 3999 (roman-decode "MMMCMXCIX")) "roman-decode MMMCMXCIX")))
