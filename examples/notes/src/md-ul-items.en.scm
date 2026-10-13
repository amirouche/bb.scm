;; md-ul-items: render buffered list items as <li> HTML.
(define md-ul-items
  (lambda (items)
    (if (pair? items)
        (xeno "string-append"
          "<li>" (md-inline (car items)) "</li>"
          (md-ul-items (cdr items)))
        "")))
