;; form-get: extract KEY from a urlencoded form body ("k1=v1&k2=v2").
;; Returns the percent-decoded value, or "" when KEY is absent.
(define form-get
  (lambda (key body)
    (form-get-scan key body 0)))
