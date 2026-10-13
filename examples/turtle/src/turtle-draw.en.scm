;; turtle-draw: program text -> SVG document, composing the whole
;; language pipeline: tokenize, parse, run, render.
(define turtle-draw
  (lambda (text)
    (turtle-segments->svg
      (turtle-run
        (turtle-parse
          (turtle-tokenize text))))))
