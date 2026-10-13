;; md-prefix?: does S start with PRE?
(define md-prefix?
  (lambda (pre s)
    (define n (xeno "string-length" pre))
    (define m (xeno "string-length" s))
    (if (< m n)
        #false
        (xeno "string=?" pre (xeno "substring" s 0 n)))))
