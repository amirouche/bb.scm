;; form-decode: percent-decode a urlencoded string.
(define form-decode
  (lambda (s)
    (form-decode-chars (string->list s))))
