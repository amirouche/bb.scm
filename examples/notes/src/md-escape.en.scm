;; md-escape: HTML-escape a string (& < > " become entities).
(define md-escape
  (lambda (s)
    (md-escape-chars (string->list s))))
