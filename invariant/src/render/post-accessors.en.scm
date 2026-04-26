;; A post is a triple: (slug title body-paragraphs)
;; - slug: string, used for the html filename
;; - title: string, escaped on render
;; - body-paragraphs: list of strings, each one a paragraph
(define post-slug       (lambda (p) (car p)))
(define post-title      (lambda (p) (car (cdr p))))
(define post-paragraphs (lambda (p) (car (cdr (cdr p)))))
