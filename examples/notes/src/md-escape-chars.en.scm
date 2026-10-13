;; md-escape-chars: HTML-escape a Mobius list of characters.
;; & < > " become entities; every other character passes through.
;; Applied by md-escape before any markdown interpretation, so that
;; user text can never inject markup.
(define md-escape-chars
  (gamma
    ((#nil) "")
    (((#\& . ,rest)) (xeno "string-append" "&amp;" (md-escape-chars rest)))
    (((#\< . ,rest)) (xeno "string-append" "&lt;" (md-escape-chars rest)))
    (((#\> . ,rest)) (xeno "string-append" "&gt;" (md-escape-chars rest)))
    (((#\" . ,rest)) (xeno "string-append" "&quot;" (md-escape-chars rest)))
    (((,c . ,rest))
     (xeno "string-append" (list->string (cons c #nil)) (md-escape-chars rest)))))
