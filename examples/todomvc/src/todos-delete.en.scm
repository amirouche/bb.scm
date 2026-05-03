;; todos-delete: given a target-id, returns a combiner that rebuilds the
;; todos list omitting the entry with that id.
(define todos-delete
  (lambda (target-id)
    (lambda (tlist)
      (if (pair? tlist)
          (begin
            (define todo (car tlist))
            (define id   (car todo))
            (if (= id target-id)
                ((todos-delete target-id) (cdr tlist))
                (cons todo ((todos-delete target-id) (cdr tlist)))))
          #nil))))
