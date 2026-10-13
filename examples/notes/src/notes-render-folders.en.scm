;; notes-render-folders: index-page fragment listing FOLDERS, each with
;; its note count and a link. NOTES is the full note alist.
(define notes-render-folders
  (lambda (folders notes)
    (if (pair? folders)
        (xeno "string-append"
          "<a class=\"folder\" href=\"/folder/" (car folders) "\">"
          "<span>" (md-escape (car folders)) "</span>"
          "<small>" (xeno "number->string" (notes-count-folder (car folders) notes))
          " notes</small></a>"
          (notes-render-folders (cdr folders) notes))
        "")))
