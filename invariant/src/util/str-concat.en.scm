;; str-concat: concatenate a list of strings (no separator).
(define str-concat
  (lambda (parts)
    (string-join "" parts)))
