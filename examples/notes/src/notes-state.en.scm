;; notes-state: application-state factory for the notes web app.
;; Called once at server start with no arguments. Returns a mutable box
;; holding #(next-id folders notes):
;;   next-id — id of the next note to be created
;;   folders — Mobius list of folder-name strings
;;   notes   — Mobius alist of (id . (folder . (title . body)))
(define notes-state
  (lambda ()
    (box (xeno "vector" 1
      (cons "inbox" (cons "work" (cons "ideas" #nil)))
      #nil))))
