;; md-next-marker: index of the first inline-markdown marker character
;; at or after index I — * (42), ` (96) or [ (91) — or (string-length S).
(define md-next-marker
  (lambda (s i)
    (define n (xeno "string-length" s))
    (define c (if (< i n) (char->integer (xeno "string-ref" s i)) 0))
    (if (= i n)
        n
        (if (or (= c 42) (= c 96) (= c 91))
            i
            (md-next-marker s (+ i 1))))))
