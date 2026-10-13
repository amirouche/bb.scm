;; notes-count-folder: number of notes in NOTES belonging to FOLDER.
;; A note entry is (id . (folder . (title . body))).
(define notes-count-folder
  (lambda (folder notes)
    (if (pair? notes)
        (if (xeno "string=?" folder (car (cdr (car notes))))
            (+ 1 (notes-count-folder folder (cdr notes)))
            (notes-count-folder folder (cdr notes)))
        0)))
