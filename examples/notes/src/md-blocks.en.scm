;; md-blocks: block-level markdown state machine over a Mobius list of
;; lines. (md-blocks LINES MODE BUF OUT): MODE "" | "p" | "ul"; BUF the
;; raw lines buffered for the current block; OUT the HTML produced so far.
;; Headings (# ## ###), bullet lists (- item), blank-line-separated
;; paragraphs.
(define md-blocks
  (lambda (lines mode buf out)
    (define line (if (pair? lines) (car lines) ""))
    (define rest (if (pair? lines) (cdr lines) #nil))
    (define empty? (if (pair? lines) (xeno "string=?" line "") #false))
    (define ul? (md-prefix? "- " line))
    (define h3? (md-prefix? "### " line))
    (define h2? (md-prefix? "## " line))
    (define h1? (md-prefix? "# " line))
    (define n (xeno "string-length" line))
    (define item (if ul? (xeno "substring" line 2 n) ""))
    (define h3txt (if h3? (xeno "substring" line 4 n) ""))
    (define h2txt (if h2? (xeno "substring" line 3 n) ""))
    (define h1txt (if h1? (xeno "substring" line 2 n) ""))
    (define in-p? (xeno "string=?" mode "p"))
    (define in-ul? (xeno "string=?" mode "ul"))
    (if (pair? lines)
        (if empty?
            (if (xeno "string=?" mode "")
                (md-blocks rest "" #nil out)
                (md-blocks rest "" #nil (md-flush out mode buf)))
            (if ul?
                (if in-ul?
                    (md-blocks rest "ul" (cons item buf) out)
                    (md-blocks rest "ul" (cons item #nil) (md-flush out mode buf)))
                (if h3?
                    (md-blocks rest "" #nil
                      (xeno "string-append" (md-flush out mode buf)
                        "<h3>" (md-inline h3txt) "</h3>"))
                    (if h2?
                        (md-blocks rest "" #nil
                          (xeno "string-append" (md-flush out mode buf)
                            "<h2>" (md-inline h2txt) "</h2>"))
                        (if h1?
                            (md-blocks rest "" #nil
                              (xeno "string-append" (md-flush out mode buf)
                                "<h1>" (md-inline h1txt) "</h1>"))
                            (if in-p?
                                (md-blocks rest "p" (cons line buf) out)
                                (md-blocks rest "p" (cons line #nil)
                                  (md-flush out mode buf))))))))
        (md-flush out mode buf))))
