;; form-decode-chars: percent-decode a Mobius list of characters.
;; "+" becomes a space; "%XX" becomes the character with hex code XX.
;; A lone "%" without two following hex digits passes through as-is.
(define form-decode-chars
  (gamma
    ((#nil) "")
    (((#\+ . ,rest))
     (xeno "string-append" " " (form-decode-chars rest)))
    (((#\% ,a ,b . ,rest))
     (xeno "string-append"
       (list->string
         (cons (integer->char (+ (* 16 (hex-digit a)) (hex-digit b))) #nil))
       (form-decode-chars rest)))
    (((,c . ,rest))
     (xeno "string-append" (list->string (cons c #nil)) (form-decode-chars rest)))))
