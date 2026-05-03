;; escape-html-char: a single char -> the HTML-escaped string for it.
(define escape-html-char
  (gamma
   ((#\<) "&lt;")
   ((#\>) "&gt;")
   ((#\&) "&amp;")
   ((#\") "&quot;")
   ((#\') "&#39;")
   ((,c) (list->string (cons c #nil)))))
