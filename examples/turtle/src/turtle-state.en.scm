;; turtle-state: application-state factory for the turtle playground.
;; Called once at server start with no arguments. The playground is
;; stateless; the box exists because serve requires a state combiner.
(define turtle-state
  (lambda ()
    (box #nil)))
