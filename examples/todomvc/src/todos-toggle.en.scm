;; todos-toggle: given a target-id, returns a combiner that maps the todos
;; list toggling the matching entry's completed flag.
(define todos-toggle
  (lambda (target-id)
    (lambda (tlist)
      (if (pair? tlist)
          (begin
            (define todo (car tlist))
            (define id   (car todo))
            (define text (car (cdr todo)))
            (define comp (car (cdr (cdr todo))))
            (cons (cons id
                    (cons text
                      (cons (if (= id target-id) (if (= comp 0) 1 0) comp)
                            #nil)))
                  ((todos-toggle target-id) (cdr tlist))))
          #nil))))
