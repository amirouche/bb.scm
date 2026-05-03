;; clicker-state: application-state factory for the clicker web app.
;; Called once at server start with no arguments.
;; Returns a mutable box holding a vector:
;;   #(score total n0 c0 n1 c1 n2 c2)
;;   score  — spendable score
;;   total  — lifetime total earned (never decremented)
;;   n0 c0  — auto-clicker (+1/click): count, current cost
;;   n1 c1  — rocket     (+5/click): count, current cost
;;   n2 c2  — solar farm (+20/click): count, current cost
(define clicker-state
  (lambda ()
    (box (xeno "vector" 0 0 0 50 0 250 0 1000))))
