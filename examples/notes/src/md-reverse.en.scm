;; md-reverse: reverse the Mobius list LST, prepending onto ACC.
;; Call as (md-reverse LST #nil). Used to restore the original line
;; order of block buffers, which are accumulated by prepending.
(define md-reverse
  (lambda (lst acc)
    (if (pair? lst)
        (md-reverse (cdr lst) (cons (car lst) acc))
        acc)))
