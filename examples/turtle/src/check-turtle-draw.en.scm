;; ~check-turtle-draw: turtle-draw composes the whole language pipeline
;; from text to an SVG document. One pen-down move north must render
;; a line inside a viewBox computed from its bounds.
(define ~check-turtle-draw
  (lambda (turtle-draw)
    (define document (turtle-draw "forward 100"))
    (assume (string-contains? document "viewBox=\"0 0 0 100\"")
            "draw one line has the right viewBox")
    (assume (string-contains? document "<line")
            "draw one line has a line element")))
