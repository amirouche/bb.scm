;; todos-remove-completed: filter out todos with comp=1.
(define todos-remove-completed
  (lambda (tlist)
    (if (pair? tlist)
        (begin
          (define todo (car tlist))
          (define comp (car (cdr (cdr todo))))
          (if (= comp 1)
              (todos-remove-completed (cdr tlist))
              (cons todo (todos-remove-completed (cdr tlist)))))
        #nil)))
