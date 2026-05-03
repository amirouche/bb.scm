;; todos-render-item: render one todo as an <li> element.
;; todo = (cons id (cons text (cons completed #nil)))
(define todos-render-item
  (lambda (todo)
    (begin
      (define id   (car todo))
      (define text (car (cdr todo)))
      (define comp (car (cdr (cdr todo))))
      (define sid  (xeno "number->string" id))
      (xeno "string-append"
        "<li" (if (= comp 1) " class=\"completed\"" "") ">"
        "<form class=\"toggle-form\" method=\"POST\""
        " action=\"/?action=toggle&id=" sid "\">"
        "<button class=\"toggle\" type=\"submit\">"
        (if (= comp 1) "&#10003;" "&#9675;")
        "</button></form>"
        "<span class=\"label\">" text "</span>"
        "<form class=\"destroy-form\" method=\"POST\""
        " action=\"/?action=delete&id=" sid "\">"
        "<button class=\"destroy\" type=\"submit\">&#215;</button>"
        "</form>"
        "</li>"))))
