;; todos-count-active: count todos with comp=0 (not completed).
(define todos-count-active
  (lambda (tlist)
    (if (pair? tlist)
        (begin
          (define comp (car (cdr (cdr (car tlist)))))
          (+ (if (= comp 0) 1 0) (todos-count-active (cdr tlist))))
        0)))
