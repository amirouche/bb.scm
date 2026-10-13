;; string-contains?: true when needle appears in haystack at any
;; position. Hand-rolled because this Chez build lacks the base
;; library procedure.
(define string-contains?
  (lambda (haystack needle)
    (define haystack-length (xeno "string-length" haystack))
    (define needle-length (xeno "string-length" needle))
    (define scan
      (lambda (index)
        (if (> (+ index needle-length) haystack-length)
            #false
            (if (xeno "string=?" needle (xeno "substring" haystack index (+ index needle-length)))
                #true
                (scan (+ index 1))))))
    (if (> needle-length haystack-length)
        #false
        (scan 0))))
