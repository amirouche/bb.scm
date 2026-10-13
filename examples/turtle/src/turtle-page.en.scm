;; turtle-page: page title, program text, and SVG document -> full
;; HTML page for the playground. Program text is HTML-escaped via
;; md-escape (pulled from the notes store) inside the textarea.
(define turtle-page
  (lambda (title program document)
    (xeno "string-append"
      "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>"
      (md-escape title)
      "</title><style>"
      "body{font-family:system-ui,sans-serif;max-width:880px;margin:2rem auto;padding:0 1rem;color:#222}"
      "h1{font-size:1.4rem}"
      "nav a{margin-right:1ex}"
      "textarea{width:100%;font-family:monospace;font-size:1rem;padding:.5rem;margin:.4rem 0;box-sizing:border-box}"
      "button{font-size:1rem;padding:.4rem 1.2rem;cursor:pointer}"
      ".drawing{margin-top:1.5rem;border:1px solid #ddd;border-radius:8px;padding:1rem;background:#fafafa}"
      ".drawing svg{max-width:100%;height:auto;display:block;margin:auto}"
      "</style></head><body>"
      "<h1>turtle playground</h1>"
      "<nav>examples:"
      " <a href=\"/?example=square\">square</a>"
      " <a href=\"/?example=spiral\">spiral</a>"
      " <a href=\"/?example=star\">star</a>"
      "</nav>"
      "<form method=\"POST\" action=\"/draw\">"
      "<textarea name=\"program\" rows=\"8\" spellcheck=\"false\">"
      (md-escape program)
      "</textarea>"
      "<button type=\"submit\">Draw</button>"
      "</form>"
      "<div class=\"drawing\">"
      document
      "</div>"
      "</body></html>")))
