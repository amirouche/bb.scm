;; md-inline: render inline markdown of a (pre-escaped) string.
(define md-inline
  (lambda (s)
    (md-inline-from s 0 "")))
