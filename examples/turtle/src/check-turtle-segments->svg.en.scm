;; ~check-turtle-segments->svg: turtle-segments->svg renders a
;; segment list to an SVG document string. The viewBox is
;; "min-x min-y width height" computed from the bounds, with integer
;; rendering for integer-valued bounds; the document opens with <svg,
;; closes with </svg>, and carries the segment colors as stroke.
(define ~check-turtle-segments->svg
  (lambda (turtle-segments->svg)
    (define square
      (cons (cons "segment" (cons 0 (cons 0 (cons 0 (cons 100 (cons "black" #nil))))))
            (cons (cons "segment" (cons 0 (cons 100 (cons 100 (cons 100 (cons "black" #nil))))))
                  (cons (cons "segment" (cons 100 (cons 100 (cons 100 (cons 0 (cons "black" #nil))))))
                        (cons (cons "segment" (cons 100 (cons 0 (cons 0 (cons 0 (cons "black" #nil))))))
                              #nil)))))
    (define document (turtle-segments->svg square))
    (assume (string-contains? document "<svg") "svg opens")
    (assume (string-contains? document "</svg>") "svg closes")
    (assume (string-contains? document "viewBox=\"0 0 100 100\"")
            "svg viewBox from bounds")
    (assume (string-contains? document "black") "svg carries segment color")))
