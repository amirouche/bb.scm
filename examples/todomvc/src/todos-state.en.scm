;; todos-state: application-state factory.
;; Returns (box (cons next-id todos-list)).
;; todos-list is a list of (cons id (cons text (cons completed #nil)))
;; where completed is 0 (active) or 1 (done).
(define todos-state
  (lambda ()
    (box (cons 1 #nil))))
