;; notes-render-notes: fragment listing the notes of FOLDER as links,
;; wrapped in <li> items (caller provides the <ul>).
(define notes-render-notes
  (lambda (folder notes)
    (if (pair? notes)
        (if (xeno "string=?" folder (car (cdr (car notes))))
            (xeno "string-append"
              "<li><a href=\"/note/"
              (xeno "number->string" (car (car notes)))
              "\">"
              (md-escape (car (cdr (cdr (car notes)))))
              "</a></li>"
              (notes-render-notes folder (cdr notes)))
            (notes-render-notes folder (cdr notes)))
        "")))
