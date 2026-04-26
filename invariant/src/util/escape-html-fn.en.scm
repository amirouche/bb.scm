;; escape-html: replace <, >, &, ", ' with HTML entities.
(define escape-html
  (lambda (s) (escape-html-loop (string->list s) "")))
