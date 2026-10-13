;; turtle-bounds: segment list -> (min-x min-y max-x max-y). The
;; bounds cover every endpoint of every segment; a segment is
;; ("segment" x1 y1 x2 y2 color). No segments yields (0 0 0 0).
(define turtle-bounds
  (lambda (segments)
    (define number-min
      (lambda (left right)
        (if (< left right) left right)))
    (define number-max
      (lambda (left right)
        (if (> left right) left right)))
    (define segment-x1
      (lambda (segment) (car (cdr segment))))
    (define segment-y1
      (lambda (segment) (car (cdr (cdr segment)))))
    (define segment-x2
      (lambda (segment) (car (cdr (cdr (cdr segment))))))
    (define segment-y2
      (lambda (segment) (car (cdr (cdr (cdr (cdr segment)))))))
    (define bounds-merge
      (lambda (bounds x1 y1 x2 y2)
        (cons (number-min (car bounds) (number-min x1 x2))
              (cons (number-min (car (cdr bounds)) (number-min y1 y2))
                    (cons (number-max (car (cdr (cdr bounds))) (number-max x1 x2))
                          (cons (number-max (car (cdr (cdr (cdr bounds))))
                                            (number-max y1 y2))
                                #nil))))))
    (define bounds-visit
      (lambda (segments bounds)
        (if (eq? segments #nil)
            bounds
            (bounds-visit (cdr segments)
                          (bounds-merge bounds
                                        (segment-x1 (car segments))
                                        (segment-y1 (car segments))
                                        (segment-x2 (car segments))
                                        (segment-y2 (car segments)))))))
    (if (eq? segments #nil)
        (cons 0 (cons 0 (cons 0 (cons 0 #nil))))
        ((lambda (x1 y1 x2 y2)
           (bounds-visit segments
                         (cons (number-min x1 x2)
                               (cons (number-min y1 y2)
                                     (cons (number-max x1 x2)
                                           (cons (number-max y1 y2)
                                                 #nil))))))
         (segment-x1 (car segments))
         (segment-y1 (car segments))
         (segment-x2 (car segments))
         (segment-y2 (car segments))))))
