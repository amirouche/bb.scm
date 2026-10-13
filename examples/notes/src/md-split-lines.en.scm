;; md-split-lines: split S on newline into a Mobius list of line strings.
;; A trailing carriage return (from browser CRLF textareas) is stripped
;; from each line.
(define md-split-lines
  (lambda (s)
    (define n (xeno "string-length" s))
    (define i (md-index-of s 10 0))
    (define raw (if (= i n) s (xeno "substring" s 0 i)))
    (define rn (xeno "string-length" raw))
    (define cr?
      (if (> rn 0)
          (= (char->integer (xeno "string-ref" raw (- rn 1))) 13)
          #false))
    (define line (if cr? (xeno "substring" raw 0 (- rn 1)) raw))
    (if (= i n)
        (if (= n 0) #nil (cons line #nil))
        (cons line (md-split-lines (xeno "substring" s (+ i 1) n))))))
