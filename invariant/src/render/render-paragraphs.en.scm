;; render-paragraphs: list of strings -> "<p>p1</p>\n<p>p2</p>..."
;; Each paragraph is HTML-escaped. The list is walked recursively
;; (no `map`, since we don't ship one).
(define render-paragraphs
  (lambda (paras)
    (if (pair? paras)
        (str-append
         (str-append (str-append "<p>" (escape-html (car paras))) "</p>\n")
         (render-paragraphs (cdr paras)))
        "")))
