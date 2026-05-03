;; string-join: concatenate a list of strings with `sep` between each.
;; (string-join "/" (list "a" "b" "c")) => "a/b/c"
;; (string-join "/" (list "a"))         => "a"
;; (string-join "/" #nil)                => ""
(define string-join
  (lambda (sep parts)
    (if (pair? parts)
        (if (pair? (cdr parts))
            (str-append (car parts)
                        (str-append sep (string-join sep (cdr parts))))
            (car parts))
        "")))
