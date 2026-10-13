;; md-inline-from: render inline markdown of S starting at index I with
;; accumulated output OUT. Supported: **bold**, *italic*, `code`,
;; [text](url). Unclosed markers render literally. Input is expected to
;; be HTML-escaped already; spans recurse through md-inline-from so that
;; nesting (e.g. a link inside bold) keeps working.
(define md-inline-from
  (lambda (s i out)
    (define n (xeno "string-length" s))
    (define m (md-next-marker s i))
    (define out2 (xeno "string-append" out (xeno "substring" s i m)))
    (define c (if (< m n) (char->integer (xeno "string-ref" s m)) 0))
    (define c2 (if (< (+ m 1) n) (char->integer (xeno "string-ref" s (+ m 1))) 0))
    (define double? (and (= c 42) (= c2 42)))
    (define k2 (if double? (md-find-pair s 42 (+ m 2)) n))
    (define k1 (md-index-of s 42 (+ m 1)))
    (define kc (md-index-of s 96 (+ m 1)))
    (define jl (md-index-of s 93 (+ m 1)))
    (define paren?
      (and (< (+ jl 1) n)
           (= (if (< (+ jl 1) n)
                  (char->integer (xeno "string-ref" s (+ jl 1)))
                  0)
              40)))
    (define kl (if paren? (md-index-of s 41 (+ jl 2)) n))
    (if (= m n)
        out2
        (if (= c 42)
            (if double?
                (if (= k2 n)
                    (md-inline-from s (+ m 2) (xeno "string-append" out2 "**"))
                    (md-inline-from s (+ k2 2)
                      (xeno "string-append" out2 "<strong>"
                        (md-inline-from (xeno "substring" s (+ m 2) k2) 0 "")
                        "</strong>")))
                (if (= k1 n)
                    (md-inline-from s (+ m 1) (xeno "string-append" out2 "*"))
                    (md-inline-from s (+ k1 1)
                      (xeno "string-append" out2 "<em>"
                        (md-inline-from (xeno "substring" s (+ m 1) k1) 0 "")
                        "</em>"))))
            (if (= c 96)
                (if (= kc n)
                    (md-inline-from s (+ m 1) (xeno "string-append" out2 "`"))
                    (md-inline-from s (+ kc 1)
                      (xeno "string-append" out2 "<code>"
                        (xeno "substring" s (+ m 1) kc)
                        "</code>")))
                (if (or (= jl n) (= kl n))
                    (md-inline-from s (+ m 1) (xeno "string-append" out2 "["))
                    (md-inline-from s (+ kl 1)
                      (xeno "string-append" out2 "<a href=\""
                        (xeno "substring" s (+ jl 2) kl)
                        "\">"
                        (md-inline-from (xeno "substring" s (+ m 1) jl) 0 "")
                        "</a>"))))))))
