;; roman-encode: integer 1..3999 -> standard Roman numeral string.
(define roman-encode
  (lambda (n)
    (define pairs
      (cons (cons 1000 "M")
            (cons (cons 900 "CM")
                  (cons (cons 500 "D")
                        (cons (cons 400 "CD")
                              (cons (cons 100 "C")
                                    (cons (cons 90 "XC")
                                          (cons (cons 50 "L")
                                                (cons (cons 40 "XL")
                                                      (cons (cons 10 "X")
                                                            (cons (cons 9 "IX")
                                                                  (cons (cons 5 "V")
                                                                        (cons (cons 4 "IV")
                                                                              (cons (cons 1 "I")
                                                                                    #nil))))))))))))))
    (roman-encode-pairs n pairs "")))
