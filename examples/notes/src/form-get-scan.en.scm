;; form-get-scan: scan urlencoded BODY for the segment "KEY=VALUE"
;; starting at index I. Returns the percent-decoded value or "".
;; Segments are separated by "&"; the first "=" of a segment separates
;; its key from its value.
(define form-get-scan
  (lambda (key body i)
    (define n (xeno "string-length" body))
    (define e (md-index-of body 38 i))
    (define eq0 (md-index-of body 61 i))
    (define eq (if (< eq0 e) eq0 n))
    (define k (xeno "string-length" key))
    (define fits (if (< eq e) (= (+ i k) eq) #false))
    (define match
      (if fits (xeno "string=?" key (xeno "substring" body i eq)) #false))
    (if match
        (form-decode (xeno "substring" body (+ eq 1) e))
        (if (= e n)
            ""
            (form-get-scan key body (+ e 1))))))
