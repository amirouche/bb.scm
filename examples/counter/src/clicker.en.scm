;; clicker: HTTP handler for the clicker web app.
;; state: box holding #(score total n0 c0 n1 c1 n2 c2)
;; req:   alist — "method" is a symbol (GET POST ...), "body" is a string.
(define clicker
  (lambda (state req)
    (begin
      (define method (cdr (xeno "assoc" "method" req)))
      (define v (unbox state))
      (define score (xeno "vector-ref" v 0))
      (define total (xeno "vector-ref" v 1))
      (define n0    (xeno "vector-ref" v 2))
      (define c0    (xeno "vector-ref" v 3))
      (define n1    (xeno "vector-ref" v 4))
      (define c1    (xeno "vector-ref" v 5))
      (define n2    (xeno "vector-ref" v 6))
      (define c2    (xeno "vector-ref" v 7))
      (define click-val (+ 1 n0 (* 5 n1) (* 20 n2)))
      (define body (cdr (xeno "assoc" "body" req)))
      (define body-len (xeno "string-length" body))
      ;; is-click: body is "action=click" (length 12)
      ;; is-buy:   body is "action=buyN"  (length 11)
      (define is-click (= body-len 12))
      (define is-buy   (= body-len 11))
      ;; buy-idx: digit char at position 10, converted to 0/1/2 (only when is-buy)
      (define buy-idx  (if is-buy (- (xeno "char->integer" (xeno "string-ref" body 10)) 48) 0))
      ;; buy-ni / buy-ci: current count and cost for the bonus being bought
      (define buy-ni   (if is-buy (xeno "vector-ref" v (+ 2 (* 2 buy-idx))) 0))
      (define buy-ci   (if is-buy (xeno "vector-ref" v (+ 3 (* 2 buy-idx))) 0))
      ;; new cost after purchase: ceiling(cost * 1.5) = (cost*3+1) / 2
      (define new-cost (xeno "quotient" (+ (* buy-ci 3) 1) 2))
      (if (eq? method (xeno "string->symbol" "POST"))
          (begin
            (if is-click
                (begin
                  (xeno "vector-set!" v 0 (+ score click-val))
                  (xeno "vector-set!" v 1 (+ total click-val)))
                (if is-buy
                    (if (< score buy-ci)
                        #false
                        (begin
                          (xeno "vector-set!" v 0 (- score buy-ci))
                          (xeno "vector-set!" v (+ 2 (* 2 buy-idx)) (+ buy-ni 1))
                          (xeno "vector-set!" v (+ 3 (* 2 buy-idx)) new-cost)))
                    #false))
            (box! state v)
            (cons (cons "status" 302)
              (cons (cons "headers" (cons (cons "location" "/") #nil))
                (cons (cons "body" "") #nil))))
          (cons (cons "status" 200)
            (cons (cons "body"
                    (xeno "string-append"
                      "<!DOCTYPE html><html lang=\"en\"><head>"
                      "<meta charset=\"utf-8\">"
                      "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
                      "<title>Clicker</title>"
                      "<style>"
                      "*{box-sizing:border-box;margin:0;padding:0}"
                      "body{background:#0f0f1a;color:#e0e0ff;font-family:'Segoe UI',system-ui,sans-serif;"
                      "display:flex;flex-direction:column;align-items:center;min-height:100vh;"
                      "padding:2rem 1rem;gap:1.5rem}"
                      "h1{font-size:1.6rem;letter-spacing:.15em;color:#aaaaff}"
                      ".scores{display:flex;gap:2rem;align-items:baseline}"
                      "#score{font-size:3.5rem;font-weight:700;color:#fff;text-shadow:0 0 24px #6666ff}"
                      ".total{font-size:1rem;color:#8888cc}"
                      ".cps{font-size:1rem;color:#8888cc}"
                      "#btn{width:160px;height:160px;border-radius:50%;"
                      "background:radial-gradient(circle at 38% 38%,#7755ff,#3311aa);"
                      "border:none;cursor:pointer;box-shadow:0 0 40px #5533ff88,0 4px 12px #0008;"
                      "font-size:3rem;transition:transform .08s,box-shadow .08s;user-select:none}"
                      "#btn:active{transform:scale(.92)}"
                      ".upgrades{display:flex;gap:1rem;flex-wrap:wrap;justify-content:center;max-width:600px}"
                      ".card{background:#1a1a2e;border:1px solid #3333aa;border-radius:12px;"
                      "padding:1rem 1.2rem;min-width:140px;text-align:center}"
                      ".card h3{font-size:.9rem;color:#aaaaff;margin-bottom:.4rem}"
                      ".card .owned{font-size:1.4rem;font-weight:700;color:#fff}"
                      ".card .pps{font-size:.75rem;color:#6666aa;margin-bottom:.6rem}"
                      ".buy-btn{background:#3322aa;color:#fff;border:none;border-radius:8px;"
                      "padding:.4rem .9rem;cursor:pointer;font-size:.85rem}"
                      ".buy-btn:disabled{background:#222244;color:#555588;cursor:default}"
                      "</style></head><body>"
                      "<h1>&#9670; CLICKER &#9670;</h1>"
                      "<div class=\"scores\">"
                      "<div id=\"score\">" (xeno "number->string" score) "</div>"
                      "<div class=\"total\">total: " (xeno "number->string" total) "</div>"
                      "<div class=\"cps\">+" (xeno "number->string" click-val) "/click</div>"
                      "</div>"
                      "<form method=\"POST\" action=\"/\">"
                      "<button id=\"btn\" name=\"action\" value=\"click\" type=\"submit\">&#127775;</button>"
                      "</form>"
                      "<div class=\"upgrades\">"
                      "<div class=\"card\"><h3>&#129302; Auto-Clicker</h3>"
                      "<div class=\"owned\">" (xeno "number->string" n0) "</div>"
                      "<div class=\"pps\">+1 per click</div>"
                      "<form method=\"POST\" action=\"/\">"
                      "<button class=\"buy-btn\" name=\"action\" value=\"buy0\" type=\"submit\""
                      (if (< score c0) " disabled" "")
                      ">Buy (" (xeno "number->string" c0) ")</button>"
                      "</form></div>"
                      "<div class=\"card\"><h3>&#128640; Rocket</h3>"
                      "<div class=\"owned\">" (xeno "number->string" n1) "</div>"
                      "<div class=\"pps\">+5 per click</div>"
                      "<form method=\"POST\" action=\"/\">"
                      "<button class=\"buy-btn\" name=\"action\" value=\"buy1\" type=\"submit\""
                      (if (< score c1) " disabled" "")
                      ">Buy (" (xeno "number->string" c1) ")</button>"
                      "</form></div>"
                      "<div class=\"card\"><h3>&#9728; Solar Farm</h3>"
                      "<div class=\"owned\">" (xeno "number->string" n2) "</div>"
                      "<div class=\"pps\">+20 per click</div>"
                      "<form method=\"POST\" action=\"/\">"
                      "<button class=\"buy-btn\" name=\"action\" value=\"buy2\" type=\"submit\""
                      (if (< score c2) " disabled" "")
                      ">Buy (" (xeno "number->string" c2) ")</button>"
                      "</form></div>"
                      "</div>"
                      "</body></html>"))
              (cons (cons "headers" #nil) #nil)))))))
