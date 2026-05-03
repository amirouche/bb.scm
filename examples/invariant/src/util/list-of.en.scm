;; list-of: same as base-library `list`. The argument tree is already
;; the cons-list we want, so we just return it.
;; We define our own because `list` lives in base-library only at
;; runtime, not in the bb add-time name index.
(define list-of (gamma (,args args)))
