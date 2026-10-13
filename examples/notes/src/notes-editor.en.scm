;; notes-editor: note editor fragment, with optional rendered preview.
;; (notes-editor MODE FOLDER ID TITLE BODY PREVIEW FOLDERS)
;;   MODE "new" — creation form (folder select, no id).
;;   MODE "edit" — save form (hidden id, folder fixed).
;;   PREVIEW — rendered markdown shown above the editor, "" for none.
;; The Preview button uses HTML5 formaction/formmethod so the same form
;; posts to /preview without any JavaScript.
(define notes-editor
  (lambda (mode folder id title body preview folders)
    (xeno "string-append"
      (if (xeno "string=?" preview "")
          ""
          (xeno "string-append"
            "<section class=\"preview\"><h2>preview</h2>"
            "<article class=\"note\">" preview "</article></section>"))
      "<section class=\"editor\">"
      "<form method=\"POST\" action=\""
      (if (xeno "string=?" mode "edit") "/save" "/add")
      "\">"
      (if (xeno "string=?" mode "edit")
          (xeno "string-append"
            "<input type=\"hidden\" name=\"id\" value=\""
            (xeno "number->string" id) "\">")
          (xeno "string-append"
            "<label>folder<select name=\"folder\">"
            (notes-folder-options folder folders)
            "</select></label>"))
      "<label>title<input name=\"title\" value=\"" (md-escape title) "\"></label>"
      "<label>body<textarea name=\"body\" rows=\"16\">"
      (md-escape body)
      "</textarea></label>"
      "<div class=\"actions\">"
      "<button type=\"submit\">Save</button>"
      "<button type=\"submit\" formaction=\"/preview\" formmethod=\"POST\">Preview</button>"
      "</div>"
      "</form>"
      "<p class=\"crumbs\">markdown: # ## ### headings &middot; **bold** &middot; "
      "*italic* &middot; `code` &middot; [text](url) &middot; - bullet lists</p>"
      "</section>")))
