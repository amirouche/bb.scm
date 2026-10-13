;; md-flush: close the current markdown block.
;; (md-flush OUT MODE BUF): MODE "" | "p" | "ul"; BUF holds the buffered
;; raw lines of the block being closed.
(define md-flush
  (gamma
    ((,out "" ,buf) out)
    ((,out "p" ,buf)
     (xeno "string-append" out "<p>" (md-inline-join (md-reverse buf #nil)) "</p>"))
    ((,out "ul" ,buf)
     (xeno "string-append" out "<ul>" (md-ul-items (md-reverse buf #nil)) "</ul>"))))
