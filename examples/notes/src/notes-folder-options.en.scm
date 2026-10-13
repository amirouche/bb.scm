;; notes-folder-options: <option> elements for the folder <select>,
;; with FOLDER marked selected when present in FOLDERS.
(define notes-folder-options
  (lambda (selected folders)
    (if (pair? folders)
        (xeno "string-append"
          "<option value=\"" (car folders) "\""
          (if (xeno "string=?" selected (car folders)) " selected" "")
          ">" (car folders) "</option>"
          (notes-folder-options selected (cdr folders)))
        "")))
