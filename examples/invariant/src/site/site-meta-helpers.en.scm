;; small accessors for the (title tagline footer) tree from site-meta.
(define site-title    (lambda (lang) (car (site-meta lang))))
(define site-tagline  (lambda (lang) (car (cdr (site-meta lang)))))
(define site-footer   (lambda (lang) (car (cdr (cdr (site-meta lang))))))
