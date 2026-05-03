;; todos: HTTP handler for the TodoMVC app.
;; state: box holding (cons next-id todos-list)
;; POST /?action=toggle&id=N  — toggle completed flag
;; POST /?action=delete&id=N  — remove todo
;; POST /?action=clear         — remove all completed
;; POST /                      — add todo (body: t=TEXT)
;; GET  /                      — render page
(define todos
  (lambda (state req)
    (begin
      (define method    (cdr (xeno "assoc" "method" req)))
      (define params    (cdr (xeno "assoc" "params" req)))
      (define body-str  (cdr (xeno "assoc" "body" req)))
      (define st        (unbox state))
      (define next-id   (car st))
      (define tlist     (cdr st))
      (define action-p  (xeno "assq" (xeno "string->symbol" "action") params))
      (define action    (if action-p (cdr action-p) ""))
      (define id-p      (xeno "assq" (xeno "string->symbol" "id") params))
      (define id-str    (if id-p (cdr id-p) "0"))
      (define id-raw    (xeno "string->number" id-str))
      (define id        (if id-raw id-raw 0))
      (define body-len  (xeno "string-length" body-str))
      ;; body for add is "t=TEXT"; text starts at byte 2
      (define text      (if (< 2 body-len)
                            (xeno "substring" body-str 2 body-len)
                            ""))
      (define is-post   (eq? method (xeno "string->symbol" "POST")))
      ;; pre-render only on GET with no action (avoids stale read after mutation)
      (define is-render (if is-post #false (xeno "string=?" action "")))
      (define active    (if is-render (todos-count-active tlist) 0))
      (define items-html (if is-render (todos-render-list tlist) ""))
      (define show-footer (if is-render (if (xeno "null?" tlist) #false #true) #false))
      (if is-post
          (begin
            (if (xeno "string=?" action "toggle")
                (box! state (cons next-id ((todos-toggle id) tlist)))
                (if (xeno "string=?" action "delete")
                    (box! state (cons next-id ((todos-delete id) tlist)))
                    (if (xeno "string=?" action "clear")
                        (box! state (cons next-id (todos-remove-completed tlist)))
                        (if (< 0 (xeno "string-length" text))
                            (box! state
                                  (cons (+ next-id 1)
                                        (cons (cons next-id (cons text (cons 0 #nil)))
                                              tlist)))
                            #false))))
            (cons (cons "status" 302)
              (cons (cons "headers" (cons (cons "location" "/") #nil))
                (cons (cons "body" "") #nil))))
          (cons (cons "status" 200)
            (cons (cons "body"
                    (xeno "string-append"
                      "<!DOCTYPE html><html lang=\"en\"><head>"
                      "<meta charset=\"utf-8\">"
                      "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
                      "<title>todos</title>"
                      "<style>"
                      "*{box-sizing:border-box;margin:0;padding:0}"
                      "body{font:14px 'Helvetica Neue',Helvetica,Arial,sans-serif;"
                      "background:#f5f5f5;color:#4d4d4d;min-height:100vh}"
                      ".todoapp{background:#fff;margin:80px auto 40px;max-width:550px;"
                      "box-shadow:0 2px 4px rgba(0,0,0,.2),0 25px 50px rgba(0,0,0,.1)}"
                      "h1{position:absolute;top:-140px;width:100%;font-size:80px;"
                      "font-weight:200;text-align:center;color:rgba(175,47,47,.45)}"
                      ".header{position:relative;padding:0}"
                      ".new-todo-form{display:flex}"
                      ".new-todo{flex:1;padding:16px 16px 16px 60px;font-size:24px;"
                      "border:none;border-bottom:1px solid #ededed;outline:none;"
                      "background:rgba(0,0,0,.003);font-style:italic;color:#999}"
                      ".new-todo:focus{color:#4d4d4d;font-style:normal}"
                      ".todo-list{list-style:none;margin:0;padding:0}"
                      ".todo-list li{position:relative;font-size:24px;border-bottom:1px solid #ededed;"
                      "display:flex;align-items:center;height:58px}"
                      ".todo-list li.completed .label{color:#d9d9d9;text-decoration:line-through}"
                      ".toggle-form{flex-shrink:0}"
                      ".toggle{width:40px;height:58px;background:none;border:none;"
                      "cursor:pointer;font-size:22px;color:#737373;outline:none}"
                      ".toggle:hover{color:#4d4d4d}"
                      ".label{flex:1;padding:0 8px;word-break:break-all;line-height:1.2}"
                      ".destroy-form{margin-right:8px}"
                      ".destroy{display:none;background:none;border:none;cursor:pointer;"
                      "font-size:22px;color:#cc9a9a;line-height:1}"
                      ".todo-list li:hover .destroy{display:block}"
                      ".footer{padding:10px 15px;text-align:center;color:#777;"
                      "border-top:1px solid #e6e6e6;display:flex;justify-content:space-between;"
                      "align-items:center;font-size:14px}"
                      ".clear-btn{background:none;border:none;cursor:pointer;color:#777;"
                      "text-decoration:underline;font-size:14px}"
                      ".clear-btn:hover{color:#333}"
                      "</style></head><body>"
                      "<section class=\"todoapp\">"
                      "<header class=\"header\"><h1>todos</h1>"
                      "<form class=\"new-todo-form\" method=\"POST\" action=\"/\">"
                      "<input class=\"new-todo\" name=\"t\" placeholder=\"What needs to be done?\" autofocus>"
                      "</form></header>"
                      "<ul class=\"todo-list\">" items-html "</ul>"
                      (if show-footer
                          (xeno "string-append"
                            "<footer class=\"footer\">"
                            "<span>" (xeno "number->string" active)
                            " item" (if (= active 1) "" "s") " left</span>"
                            "<form method=\"POST\" action=\"/?action=clear\">"
                            "<button class=\"clear-btn\" type=\"submit\">Clear completed</button>"
                            "</form></footer>")
                          "")
                      "</section>"
                      "</body></html>"))
              (cons (cons "headers" #nil) #nil)))))))
