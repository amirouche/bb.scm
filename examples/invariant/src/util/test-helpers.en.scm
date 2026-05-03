;; test-helpers: smoke tests for the util layer.
(define test-string-join
  (lambda ()
    (string-join ", " (cons "a" (cons "b" (cons "c" #nil))))))

(define test-str-concat
  (lambda ()
    (str-concat (cons "<p>" (cons "hi" (cons "</p>" #nil))))))
