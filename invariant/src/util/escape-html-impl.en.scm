;; escape-html-loop: char-list, accumulator-string -> escaped string.
(define escape-html-loop
  (lambda (chars acc)
    (if (pair? chars)
        (escape-html-loop (cdr chars)
                          (str-append acc (escape-html-char (car chars))))
        acc)))
