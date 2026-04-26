;; str-append: two-string concatenation via list->string + mob-append.
(define str-append
  (lambda (a b)
    (list->string (mob-append (string->list a) (string->list b)))))
