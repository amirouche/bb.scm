;; turtle-run: walk a command tree from state (0, 0, 0, pen-down,
;; black) — x, y, heading in degrees clockwise from north — and emit
;; one ("segment" x1 y1 x2 y2 color) for every pen-down move.
;; ("error" word) commands and anything malformed are skipped, never
;; raised. repeat bodies are expanded first to a flat command list
;; with a frame stack (each frame is a remaining command list), so
;; no combiner-level recursion is needed at run time. walk-move is
;; defined before walk and receives walk as an explicit continuation
;; argument, keeping the internal defines strictly sequential: no
;; mutual recursion across combiners and no forward references.
(define turtle-run
  (lambda (commands)
    (define copies
      (lambda (count children tail)
        (if (= count 0)
            tail
            (cons children (copies (- count 1) children tail)))))
    (define expand
      (lambda (frames)
        (if (eq? frames #nil)
            #nil
            (if (eq? (car frames) #nil)
                (expand (cdr frames))
                ((lambda (command)
                   (if (pair? command)
                       (if (string? (car command))
                           (if (xeno "string=?" (car command) "repeat")
                               (if (pair? (cdr command))
                                   (if (pair? (cdr (cdr command)))
                                       (expand (copies (car (cdr command))
                                                       (car (cdr (cdr command)))
                                                       (cons (cdr (car frames))
                                                             (cdr frames))))
                                       (expand (cons (cdr (car frames))
                                                     (cdr frames))))
                                   (expand (cons (cdr (car frames))
                                                 (cdr frames))))
                               (cons command
                                     (expand (cons (cdr (car frames))
                                                  (cdr frames)))))
                           (expand (cons (cdr (car frames))
                                         (cdr frames))))
                       (expand (cons (cdr (car frames))
                                     (cdr frames)))))
                 (car (car frames)))))))
    (define walk-move
      (lambda (continue sign rest command x y heading pen-down color)
        (if (pair? (cdr command))
            ((lambda (n)
               ((lambda (radians)
                  ((lambda (next-x next-y)
                     (if pen-down
                         (cons (cons "segment"
                                     (cons x
                                           (cons y
                                                 (cons next-x
                                                       (cons next-y
                                                             (cons color
                                                                   #nil))))))
                               (continue rest next-x next-y heading pen-down color))
                         (continue rest next-x next-y heading pen-down color)))
                   (+ x (* sign n (xeno "sin" radians)))
                   (+ y (* sign n (xeno "cos" radians)))))
                (* heading (xeno "atan" 1) (/ 1 45))))
             (car (cdr command)))
            (continue rest x y heading pen-down color))))
    (define walk
      (lambda (flat x y heading pen-down color)
        (if (eq? flat #nil)
            #nil
            ((lambda (command)
               (if (pair? command)
                   (if (string? (car command))
                       (if (xeno "string=?" (car command) "forward")
                           (walk-move walk 1 (cdr flat) command x y heading pen-down color)
                           (if (xeno "string=?" (car command) "backward")
                               (walk-move walk -1 (cdr flat) command x y heading pen-down color)
                               (if (xeno "string=?" (car command) "left")
                                   (if (pair? (cdr command))
                                       (walk (cdr flat)
                                             x y (- heading (car (cdr command)))
                                             pen-down color)
                                       (walk (cdr flat) x y heading pen-down color))
                                   (if (xeno "string=?" (car command) "right")
                                       (if (pair? (cdr command))
                                           (walk (cdr flat)
                                                 x y (+ heading (car (cdr command)))
                                                 pen-down color)
                                           (walk (cdr flat)
                                                 x y heading pen-down color))
                                       (if (xeno "string=?" (car command) "penup")
                                           (walk (cdr flat)
                                                 x y heading #false color)
                                           (if (xeno "string=?" (car command) "pendown")
                                               (walk (cdr flat)
                                                     x y heading #true color)
                                               (if (xeno "string=?" (car command) "color")
                                                   (if (pair? (cdr command))
                                                       (walk (cdr flat)
                                                             x y heading pen-down
                                                             (car (cdr command)))
                                                       (walk (cdr flat)
                                                             x y heading pen-down color))
                                                   (walk (cdr flat)
                                                         x y heading pen-down color))))))))
                       (walk (cdr flat) x y heading pen-down color))
                   (walk (cdr flat) x y heading pen-down color)))
             (car flat)))))
    (walk (expand (cons commands #nil)) 0 0 0 #true "black")))
