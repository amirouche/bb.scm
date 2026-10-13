;; turtle-segments->svg: segment list -> SVG document string. The
;; viewBox is "min-x min-y width height" computed from turtle-bounds;
;; y is flipped at render time because SVG y grows south while turtle
;; y grows north: render-y = (min-y + max-y) - y, which keeps every
;; point inside the viewBox. Integer-valued numbers render as
;; integers. Each segment renders as a line element carrying its
;; color as stroke.
(define turtle-segments->svg
  (lambda (segments)
    (define number-render
      (lambda (number)
        (if (integer? number)
            (xeno "number->string" number)
            (if (float? number)
                (if (= number (xeno "round" number))
                    (xeno "number->string" (xeno "exact" number))
                    (xeno "number->string" number))
                (xeno "number->string" number)))))
    (define segment-x1
      (lambda (segment) (car (cdr segment))))
    (define segment-y1
      (lambda (segment) (car (cdr (cdr segment)))))
    (define segment-x2
      (lambda (segment) (car (cdr (cdr (cdr segment))))))
    (define segment-y2
      (lambda (segment) (car (cdr (cdr (cdr (cdr segment)))))))
    (define segment-color
      (lambda (segment) (car (cdr (cdr (cdr (cdr (cdr segment))))))))
    (define bounds (turtle-bounds segments))
    (define min-x (car bounds))
    (define min-y (car (cdr bounds)))
    (define max-x (car (cdr (cdr bounds))))
    (define max-y (car (cdr (cdr (cdr bounds)))))
    (define width (- max-x min-x))
    (define height (- max-y min-y))
    (define render-y
      (lambda (y) (- (+ min-y max-y) y)))
    (define line-render
      (lambda (segment)
        ((lambda (x1 y1 x2 y2 color)
           (xeno "string-append"
                 "<line x1=\"" (number-render x1)
                 "\" y1=\"" (number-render (render-y y1))
                 "\" x2=\"" (number-render x2)
                 "\" y2=\"" (number-render (render-y y2))
                 "\" stroke=\"" color "\"/>"))
         (segment-x1 segment)
         (segment-y1 segment)
         (segment-x2 segment)
         (segment-y2 segment)
         (segment-color segment))))
    (define lines-render
      (lambda (segments)
        (if (eq? segments #nil)
            ""
            (xeno "string-append"
                  (line-render (car segments))
                  (lines-render (cdr segments))))))
    (xeno "string-append"
          "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\""
          (number-render min-x) " " (number-render min-y) " "
          (number-render width) " " (number-render height)
          "\" width=\"" (number-render width)
          "\" height=\"" (number-render height)
          "\">"
          (lines-render segments)
          "</svg>")))
