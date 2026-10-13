;; ~check-roman-roundtrip: roman-encode and roman-decode agree.
;; The check receives the roman-encode combiner as its argument;
;; roman-decode is resolved from the store at check time.
(define ~check-roman-roundtrip
  (lambda (roman-encode)
    (assume (xeno "string=?" "MCMXCIV" (roman-encode (roman-decode "MCMXCIV")))
      "roundtrip MCMXCIV")
    (assume (xeno "string=?" "XL" (roman-encode (roman-decode "XL")))
      "roundtrip XL")
    (assume (xeno "string=?" "MMMCMXCIX" (roman-encode (roman-decode "MMMCMXCIX")))
      "roundtrip MMMCMXCIX")
    (assume (= 2024 (roman-decode (roman-encode 2024)))
      "roundtrip 2024")))
