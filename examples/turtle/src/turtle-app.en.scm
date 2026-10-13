;; turtle-app: HTTP request handler for the turtle playground.
;; state — box (unused; the playground is stateless)
;; req   — alist: "method" (symbol), "path" (string), "params" (alist),
;;         "body" (raw urlencoded string for POST forms)
;;
;; Routes:
;;   GET  /                    playground with the selected example
;;   GET  /?example=<name>     playground with that preset
;;   POST /draw                render the submitted program
(define turtle-app
  (lambda (state req)
    (define method (cdr (xeno "assoc" "method" req)))
    (define path (cdr (xeno "assoc" "path" req)))
    (define params (cdr (xeno "assoc" "params" req)))
    (define body (cdr (xeno "assoc" "body" req)))
    (define post? (eq? method (xeno "string->symbol" "POST")))
    (define root? (or (xeno "string=?" path "")
                      (xeno "string=?" path "/")))
    (define draw? (xeno "string=?" path "/draw"))
    (define example-pair
      (xeno "assoc" (xeno "string->symbol" "example") params))
    (define example-name (if example-pair (cdr example-pair) "square"))
    (define preset (turtle-example example-name))
    (define submitted (form-get "program" body))
    (define program
      (if post?
          (if (xeno "string=?" submitted "") preset submitted)
          preset))
    (define respond
      (lambda (status content)
        (cons (cons "status" status)
              (cons (cons "body" content)
                    (cons (cons "headers" #nil) #nil)))))
    (if (if post? draw? #false)
        (respond 200
          (turtle-page "turtle playground" program (turtle-draw program)))
        (if (if post? #false root?)
            (respond 200
              (turtle-page "turtle playground" preset (turtle-draw preset)))
            (respond 404 "not found")))))
