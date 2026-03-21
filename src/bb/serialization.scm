(library (bb serialization)

  (export scheme-write-value
          sorted-alist->string
          ~check-serialization-atoms
          ~check-serialization-pairs
          ~check-serialization-sorted-alist)

  (import (chezscheme)
          (bb values))

  ;; Deterministic serialization for Mobius store files.
  ;; All association lists are sorted lexicographically by key.
  ;; The output is readable by a standard Scheme `read` call.

  ;; Serialize a Mobius value to a string
  (define scheme-write-value
    (lambda (value)
      (let ((port (open-output-string)))
        (write-value value port)
        (get-output-string port))))

  (define write-value
    (lambda (value port)
      (cond
       ;; Sentinel singletons — write as (mobius-primitive-constant-ref N)
       ((mobius-nil? value)
        (display "(mobius-primitive-constant-ref 0)" port))

       ((mobius-void? value)
        (display "(mobius-primitive-constant-ref 3)" port))

       ((mobius-eof? value)
        (display "(mobius-primitive-constant-ref 4)" port))

       ;; Boolean
       ((boolean? value)
        (display (if value "#t" "#f") port))

       ;; String — escape special characters
       ((string? value)
        (display "\"" port)
        (let loop ((index 0))
          (when (< index (string-length value))
            (let ((char (string-ref value index)))
              (cond
               ((char=? char #\") (display "\\\"" port))
               ((char=? char #\\) (display "\\\\" port))
               ((char=? char #\newline) (display "\\n" port))
               ((char=? char #\tab) (display "\\t" port))
               ((char=? char #\return) (display "\\r" port))
               (else (display char port))))
            (loop (+ index 1))))
        (display "\"" port))

       ;; Character
       ((char? value)
        (cond
         ((char=? value #\space) (display "#\\space" port))
         ((char=? value #\newline) (display "#\\newline" port))
         ((char=? value #\tab) (display "#\\tab" port))
         ((char=? value #\return) (display "#\\return" port))
         (else
          (display "#\\" port)
          (display value port))))

       ;; Integer
       ((and (integer? value) (exact? value))
        (display value port))

       ;; Float
       ((flonum? value)
        (display value port))

       ;; Symbol
       ((symbol? value)
        (display (symbol->string value) port))

       ;; Pair / list
       ((pair? value)
        (display "(" port)
        (write-value (car value) port)
        (let loop ((tail (cdr value)))
          (cond
           ((null? tail)
            (display ")" port))
           ((pair? tail)
            (display " " port)
            (write-value (car tail) port)
            (loop (cdr tail)))
           (else
            (display " . " port)
            (write-value tail port)
            (display ")" port)))))

       (else
        (error 'scheme-write-value "cannot serialize" value)))))

  ;; Sort an alist by key (string representation) and serialize
  (define sorted-alist->string
    (lambda (alist)
      (let* ((sorted (sort (lambda (a b)
                             (string<? (symbol->string (car a))
                                       (symbol->string (car b))))
                           alist))
             (port (open-output-string)))
        (display "(" port)
        (let loop ((remaining sorted)
                   (first? #t))
          (unless (null? remaining)
            (let ((pair (car remaining)))
              (unless first? (display "\n " port))
              (display "(" port)
              (write-value (car pair) port)
              (display " . " port)
              (write-value (cdr pair) port)
              (display ")" port))
            (loop (cdr remaining) #f)))
        (display ")" port)
        (get-output-string port))))

  ;; --- Tests ---

  (define ~check-serialization-atoms
    (lambda ()
      (assert (equal? "42" (scheme-write-value 42)))
      (assert (equal? "\"hello\"" (scheme-write-value "hello")))
      (assert (equal? "#t" (scheme-write-value #t)))
      (assert (equal? "#f" (scheme-write-value #f)))
      (assert (equal? "(mobius-primitive-constant-ref 0)" (scheme-write-value mobius-nil)))
      (assert (equal? "\"line\\nbreak\"" (scheme-write-value "line\nbreak")))))

  (define ~check-serialization-pairs
    (lambda ()
      (assert (equal? "(1 . 2)" (scheme-write-value (cons 1 2))))
      ;; List with mobius-nil terminator
      (assert (equal? "(1 2 3)"
                       (scheme-write-value
                        (cons 1 (cons 2 (cons 3 mobius-nil))))))))

  (define ~check-serialization-sorted-alist
    (lambda ()
      ;; Keys sorted alphabetically
      (let ((result (sorted-alist->string
                     '((body . "test")
                       (author . "Amir")
                       (checks . ())))))
        (assert (string? result))
        ;; author comes before body, body before checks
        (assert (< (string-contains result "author")
                    (string-contains result "body")))
        (assert (< (string-contains result "body")
                    (string-contains result "checks"))))))

  ;; Helper for string-contains
  (define string-contains
    (lambda (haystack needle)
      (let ((h-len (string-length haystack))
            (n-len (string-length needle)))
        (let loop ((index 0))
          (cond
           ((> (+ index n-len) h-len) #f)
           ((string=? (substring haystack index (+ index n-len)) needle) index)
           (else (loop (+ index 1))))))))

  )
