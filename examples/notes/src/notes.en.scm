;; notes: HTTP request handler for the notes web app.
;; state — box holding #(next-id folders notes) from notes-state
;; req   — alist: "method" (symbol), "path" (string), "params" (alist),
;;         "body" (raw urlencoded string for POST forms)
;;
;; Routes:
;;   GET  /                      folder overview
;;   GET  /folder/<name>         notes of a folder
;;   GET  /note/<id>              note rendered as markdown
;;   GET  /new?folder=<name>     editor (create)
;;   GET  /edit/<id>             editor (edit)
;;   POST /add                   create note       -> 302 /note/<id>
;;   POST /save                  update note       -> 302 /note/<id>
;;   POST /preview               re-render editor with markdown preview
;;   POST /delete                remove note       -> 302 /folder/<name>
;;   POST /folder-add            create folder     -> 302 /
(define notes
  (lambda (state req)
    (define method (cdr (xeno "assoc" "method" req)))
    (define path (cdr (xeno "assoc" "path" req)))
    (define params (cdr (xeno "assoc" "params" req)))
    (define body (cdr (xeno "assoc" "body" req)))
    (define v (unbox state))
    (define next-id (xeno "vector-ref" v 0))
    (define folders (xeno "vector-ref" v 1))
    (define notes-alist (xeno "vector-ref" v 2))
    (define post? (eq? method (xeno "string->symbol" "POST")))
    ;; --- path analysis ---
    ;; transparenturing joins segments as "/" + s, separated by "/",
    ;; so multi-segment paths arrive as "/folder//name"; the root is "".
    (define n-path (xeno "string-length" path))
    (define root? (or (xeno "string=?" path "") (xeno "string=?" path "/")))
    (define new? (xeno "string=?" path "/new"))
    (define folder-p? (md-prefix? "/folder//" path))
    (define folder-name (if folder-p? (xeno "substring" path 9 n-path) ""))
    (define note-p? (md-prefix? "/note//" path))
    (define note-id-str (if note-p? (xeno "substring" path 7 n-path) ""))
    (define note-id (if note-p? (xeno "string->number" note-id-str) #false))
    (define edit-p? (md-prefix? "/edit//" path))
    (define edit-id-str (if edit-p? (xeno "substring" path 7 n-path) ""))
    (define edit-id (if edit-p? (xeno "string->number" edit-id-str) #false))
    ;; --- form fields (POST bodies are urlencoded) ---
    (define f-folder (form-get "folder" body))
    (define f-title (form-get "title" body))
    (define f-body (form-get "body" body))
    (define f-id-str (form-get "id" body))
    (define f-id (xeno "string->number" f-id-str))
    (define f-name (form-get "name" body))
    ;; --- lookups ---
    (define note-entry (if note-id (xeno "assoc" note-id notes-alist) #false))
    (define edit-entry (if edit-id (xeno "assoc" edit-id notes-alist) #false))
    (define f-entry (if f-id (xeno "assoc" f-id notes-alist) #false))
    (define q-folder-pair (xeno "assoc" (xeno "string->symbol" "folder") params))
    (define q-folder
      (if (if q-folder-pair (xeno "member" (cdr q-folder-pair) folders) #false)
          (cdr q-folder-pair)
          (car folders)))
    (define folder-exists (if (xeno "member" folder-name folders) #true #false))
    ;; --- response helpers ---
    (define respond
      (lambda (status content)
        (cons (cons "status" status)
              (cons (cons "body" content)
                    (cons (cons "headers" #nil) #nil)))))
    (define redirect
      (lambda (location)
        (cons (cons "status" 302)
              (cons (cons "headers" (cons (cons "location" location) #nil))
                    (cons (cons "body" "") #nil)))))
    ;; --- GET pages ---
    (define page-index
      (notes-page "notes"
        (xeno "string-append"
          "<section class=\"folders\">"
          (notes-render-folders folders notes-alist)
          "</section>"
          "<form method=\"POST\" action=\"/folder-add\">"
          "<label>new folder<input name=\"name\" placeholder=\"project-x\"></label>"
          "<div class=\"actions\"><button type=\"submit\">Create folder</button></div>"
          "</form>")))
    (define folder-list (notes-render-notes folder-name notes-alist))
    (define page-folder
      (notes-page (xeno "string-append" "notes — " (md-escape folder-name))
        (xeno "string-append"
          "<nav class=\"crumbs\"><a href=\"/\">folders</a> / "
          (md-escape folder-name) "</nav>"
          "<ul class=\"notelist\">" folder-list "</ul>"
          "<div class=\"actions\">"
          "<a class=\"btn\" href=\"/new?folder=" folder-name "\">&#43; new note</a>"
          "</div>")))
    (define note-folder (if note-entry (car (cdr note-entry)) ""))
    (define note-title (if note-entry (car (cdr (cdr note-entry))) ""))
    (define note-body (if note-entry (cdr (cdr (cdr note-entry))) ""))
    (define id-str (xeno "number->string" (if note-id note-id 0)))
    (define page-note
      (notes-page (md-escape note-title)
        (xeno "string-append"
          "<nav class=\"crumbs\"><a href=\"/\">folders</a> / "
          "<a href=\"/folder/" note-folder "\">" (md-escape note-folder) "</a>"
          " / #" id-str "</nav>"
          "<article class=\"note\">" (md-render note-body) "</article>"
          "<div class=\"actions\">"
          "<a class=\"btn\" href=\"/edit/" id-str "\">edit</a>"
          "<form class=\"inline\" method=\"POST\" action=\"/delete\">"
          "<input type=\"hidden\" name=\"id\" value=\"" id-str "\">"
          "<button type=\"submit\" class=\"danger\">delete</button>"
          "</form>"
          "</div>")))
    (define page-new
      (notes-page "new note"
        (notes-editor "new" q-folder 0 "" "" "" folders)))
    (define page-edit
      (if edit-entry
          (notes-page
            (xeno "string-append" "edit — "
              (md-escape (car (cdr (cdr edit-entry)))))
            (notes-editor "edit"
              (car (cdr edit-entry))
              edit-id
              (car (cdr (cdr edit-entry)))
              (cdr (cdr (cdr edit-entry)))
              ""
              folders))
          "not found"))
    ;; --- POST /preview: editor + rendered markdown, no save ---
    (define preview-html (md-render f-body))
    (define pv-edit? (if f-id #true #false))
    (define pv-folder
      (if (if f-entry (xeno "member" (car (cdr f-entry)) folders) #false)
          (car (cdr f-entry))
          (if (xeno "member" f-folder folders) f-folder (car folders))))
    (define pv-title (if (xeno "string=?" f-title "") "untitled" f-title))
    (define page-preview
      (notes-page "preview"
        (notes-editor
          (if pv-edit? "edit" "new")
          pv-folder
          (if f-id f-id 0)
          pv-title
          f-body
          preview-html
          folders)))
    ;; --- dispatch ---
    (if post?
        (if (xeno "string=?" path "/add")
            (begin
              (xeno "vector-set!" v 2
                (cons (cons next-id
                        (cons (if (xeno "member" f-folder folders) f-folder (car folders))
                          (cons (if (xeno "string=?" f-title "") "untitled" f-title)
                            f-body)))
                  notes-alist))
              (xeno "vector-set!" v 0 (+ next-id 1))
              (box! state v)
              (redirect (xeno "string-append" "/note/"
                (xeno "number->string" next-id))))
            (if (xeno "string=?" path "/save")
                (if f-entry
                    (begin
                      (xeno "vector-set!" v 2
                        (cons (cons f-id
                                (cons (car (cdr f-entry))
                                  (cons (if (xeno "string=?" f-title "")
                                            (car (cdr (cdr f-entry)))
                                            f-title)
                                    f-body)))
                          (xeno "remq" f-entry notes-alist)))
                      (box! state v)
                      (redirect (xeno "string-append" "/note/" (xeno "number->string" f-id))))
                    (respond 404 "no such note"))
                (if (xeno "string=?" path "/delete")
                    (if f-entry
                        (begin
                          (xeno "vector-set!" v 2 (xeno "remq" f-entry notes-alist))
                          (box! state v)
                          (redirect (xeno "string-append" "/folder/" (car (cdr f-entry)))))
                        (redirect "/"))
                    (if (xeno "string=?" path "/folder-add")
                        (begin
                          (if (and (notes-name-ok? f-name 0)
                                   (if (xeno "member" f-name folders) #false #true))
                              (xeno "vector-set!" v 1 (cons f-name folders))
                              0)
                          (box! state v)
                          (redirect "/"))
                        (if (xeno "string=?" path "/preview")
                            (respond 200 page-preview)
                            (respond 404 "not found"))))))
        (if root?
            (respond 200 page-index)
            (if (and folder-p? folder-exists)
                (respond 200 page-folder)
                (if (and note-p? note-id note-entry)
                    (respond 200 page-note)
                    (if new?
                        (respond 200 page-new)
                        (if (and edit-p? edit-id edit-entry)
                            (respond 200 page-edit)
                            (respond 404 "not found")))))))))
