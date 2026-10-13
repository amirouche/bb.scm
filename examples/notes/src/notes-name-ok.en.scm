;; notes-name-ok?: is S a valid folder name when scanned from index I?
;; Valid names are non-empty and contain only [a-zA-Z0-9_-].
;; Call as (notes-name-ok? S 0).
(define notes-name-ok?
  (lambda (s i)
    (define n (xeno "string-length" s))
    (define c (if (< i n) (char->integer (xeno "string-ref" s i)) 48))
    (define ok
      (or (= c 45)
          (= c 95)
          (and (> c 47) (< c 58))
          (and (> c 64) (< c 91))
          (and (> c 96) (< c 123))))
    (if (= i n)
        (if (= n 0) #false #true)
        (if ok (notes-name-ok? s (+ i 1)) #false))))
