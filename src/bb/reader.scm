(library (bb reader)

  (export mobius-read
          mobius-read-all
          mobius-read-string
          mobius-read-all-string
          ~check-reader-integers
          ~check-reader-hex-integers
          ~check-reader-floats
          ~check-reader-strings
          ~check-reader-characters
          ~check-reader-hash-identifiers
          ~check-reader-symbols
          ~check-reader-lists
          ~check-reader-pairs
          ~check-reader-patterns
          ~check-reader-catamorphic-patterns
          ~check-reader-predicate-guard
          ~check-reader-comments
          ~check-reader-datum-comments
          ~check-reader-nested
          ~check-reader-lang-directive)

  (import (chezscheme)
          (bb values))

  ;; The Mobius round-surface reader. Parses S-expressions with
  ;; Mobius-specific extensions:
  ;;
  ;; - Hash identifiers: #nil, #true, #false, #void, #eof
  ;; - Pattern syntax: ,x (bind), ,(x) (catamorphic bind), ,_ (wildcard)
  ;; - Predicate guard: (? pred ,x)
  ;; - Hex integers: 0xFF, 0xDEADBEEF (arbitrary precision)
  ;; - Characters: #\a, #\space, #\newline, #\tab, #\return
  ;; - Datum comments: #; (comments out next expression)
  ;; - Lang directive: #lang round (accepted and ignored)

  ;; --- Character classification ---

  (define whitespace?
    (lambda (char)
      (or (char=? char #\space)
          (char=? char #\newline)
          (char=? char #\tab)
          (char=? char #\return))))

  (define delimiter?
    (lambda (char)
      (or (whitespace? char)
          (char=? char #\()
          (char=? char #\))
          (char=? char #\{)
          (char=? char #\})
          (char=? char #\;)
          (char=? char #\:)
          (char=? char #\')
          (char=? char #\`)
          (char=? char #\")
          (char=? char #\,))))

  (define identifier-start?
    (lambda (char)
      (or (char-alphabetic? char)
          (char=? char #\+)
          (char=? char #\-)
          (char=? char #\*)
          (char=? char #\/)
          (char=? char #\<)
          (char=? char #\>)
          (char=? char #\=)
          (char=? char #\?)
          (char=? char #\!)
          (char=? char #\_)
          (char=? char #\~))))

  (define identifier-continue?
    (lambda (char)
      (not (or (whitespace? char)
               (delimiter? char)))))

  (define digit?
    (lambda (char)
      (and (char>=? char #\0)
           (char<=? char #\9))))

  (define hex-digit?
    (lambda (char)
      (or (digit? char)
          (and (char>=? char #\a) (char<=? char #\f))
          (and (char>=? char #\A) (char<=? char #\F)))))

  ;; --- Port helpers ---

  (define peek
    (lambda (port)
      (lookahead-char port)))

  (define advance
    (lambda (port)
      (read-char port)))

  (define skip-whitespace
    (lambda (port)
      (let loop ()
        (let ((char (peek port)))
          (when (and (not (eof-object? char))
                     (whitespace? char))
            (advance port)
            (loop))))))

  (define skip-line-comment
    (lambda (port)
      (let loop ()
        (let ((char (advance port)))
          (unless (or (eof-object? char)
                      (char=? char #\newline))
            (loop))))))

  (define skip-whitespace-and-comments
    (lambda (port)
      (let loop ()
        (skip-whitespace port)
        (let ((char (peek port)))
          (when (and (not (eof-object? char))
                     (char=? char #\;))
            (skip-line-comment port)
            (loop))))))

  ;; --- Token reading ---

  (define read-collected
    (lambda (port predicate)
      (let loop ((characters '()))
        (let ((char (peek port)))
          (if (or (eof-object? char)
                  (not (predicate char)))
              (list->string (reverse characters))
              (begin
                (advance port)
                (loop (cons char characters))))))))

  (define read-string-literal
    (lambda (port)
      ;; Opening quote already consumed
      (let loop ((characters '()))
        (let ((char (advance port)))
          (cond
           ((eof-object? char)
            (error 'mobius-read "unterminated string"))
           ((char=? char #\")
            (list->string (reverse characters)))
           ((char=? char #\\)
            (let ((escaped (advance port)))
              (cond
               ((eof-object? escaped)
                (error 'mobius-read "unterminated string escape"))
               ((char=? escaped #\\) (loop (cons #\\ characters)))
               ((char=? escaped #\") (loop (cons #\" characters)))
               ((char=? escaped #\n) (loop (cons #\newline characters)))
               ((char=? escaped #\t) (loop (cons #\tab characters)))
               ((char=? escaped #\r) (loop (cons #\return characters)))
               (else (error 'mobius-read "unknown escape" escaped)))))
           (else
            (loop (cons char characters))))))))

  (define read-number
    (lambda (port first-char)
      ;; first-char is a digit, +, or -
      (let* ((sign-string (if (or (char=? first-char #\+)
                                  (char=? first-char #\-))
                              (string first-char)
                              ""))
             (start (if (string=? sign-string "")
                        (string first-char)
                        (let ((next (peek port)))
                          (if (and (not (eof-object? next))
                                   (or (digit? next)
                                       (char=? next #\.)))
                              (begin (advance port) (string next))
                              ;; It's an identifier like + or -
                              (begin #f))))))
        (if (not start)
            ;; Return as symbol
            (let ((rest (read-collected port identifier-continue?)))
              (string->symbol (string-append sign-string rest)))
            ;; Check for hex
            (if (and (string=? start "0")
                     (let ((next (peek port)))
                       (and (not (eof-object? next))
                            (or (char=? next #\x)
                                (char=? next #\X)))))
                ;; Hex integer
                (begin
                  (advance port) ;; consume x
                  (let ((hex-digits (read-collected port hex-digit?)))
                    (when (string=? hex-digits "")
                      (error 'mobius-read "empty hex literal"))
                    (parse-hex-string hex-digits)))
                ;; Decimal number
                (let* ((integer-part (string-append start (read-collected port digit?)))
                       (next (peek port))
                       (has-dot (and (not (eof-object? next))
                                    (char=? next #\.))))
                  (if has-dot
                      ;; Float
                      (begin
                        (advance port)
                        (let* ((fraction-part (read-collected port digit?))
                               (next2 (peek port))
                               (has-exponent (and (not (eof-object? next2))
                                                  (or (char=? next2 #\e)
                                                      (char=? next2 #\E)))))
                          (if has-exponent
                              (begin
                                (advance port)
                                (let* ((exponent-sign
                                        (let ((es (peek port)))
                                          (if (and (not (eof-object? es))
                                                   (or (char=? es #\+)
                                                       (char=? es #\-)))
                                              (begin (advance port) (string es))
                                              "")))
                                       (exponent-digits (read-collected port digit?)))
                                  (string->number
                                   (string-append sign-string integer-part
                                                  "." fraction-part
                                                  "e" exponent-sign exponent-digits))))
                              (string->number
                               (string-append sign-string integer-part
                                              "." fraction-part)))))
                      ;; Integer
                      (let ((next3 (peek port)))
                        (if (and (not (eof-object? next3))
                                 (or (char=? next3 #\e)
                                     (char=? next3 #\E)))
                            ;; Scientific notation without dot
                            (begin
                              (advance port)
                              (let* ((exponent-sign
                                      (let ((es (peek port)))
                                        (if (and (not (eof-object? es))
                                                 (or (char=? es #\+)
                                                     (char=? es #\-)))
                                            (begin (advance port) (string es))
                                            "")))
                                     (exponent-digits (read-collected port digit?)))
                                (string->number
                                 (string-append sign-string integer-part
                                                "e" exponent-sign exponent-digits))))
                            (string->number
                             (string-append sign-string integer-part)))))))))))

  ;; Parse the hex literal format for string->number 0x prefix
  ;; Chez's string->number doesn't support 0x prefix, so we parse manually
  (define parse-hex-string
    (lambda (hex-string)
      (let loop ((index 0)
                 (result 0))
        (if (= index (string-length hex-string))
            result
            (let* ((char (string-ref hex-string index))
                   (digit-value
                    (cond
                     ((and (char>=? char #\0) (char<=? char #\9))
                      (- (char->integer char) (char->integer #\0)))
                     ((and (char>=? char #\a) (char<=? char #\f))
                      (+ 10 (- (char->integer char) (char->integer #\a))))
                     ((and (char>=? char #\A) (char<=? char #\F))
                      (+ 10 (- (char->integer char) (char->integer #\A))))
                     (else (error 'parse-hex "invalid hex digit" char)))))
              (loop (+ index 1)
                    (+ (* result 16) digit-value)))))))

  (define read-hash-token
    (lambda (port)
      ;; # already consumed. Next char determines the token type.
      (let ((char (peek port)))
        (cond
         ((eof-object? char)
          (error 'mobius-read "unexpected eof after #"))

         ;; Character literal: #\x
         ((char=? char #\\)
          (advance port)
          (let ((char-value (advance port)))
            (when (eof-object? char-value)
              (error 'mobius-read "unexpected eof in character literal"))
            ;; Check for named characters
            (if (and (char-alphabetic? char-value)
                     (let ((next (peek port)))
                       (and (not (eof-object? next))
                            (char-alphabetic? next))))
                ;; Multi-character name
                (let* ((rest (read-collected port char-alphabetic?))
                       (name (string-append (string char-value) rest)))
                  (cond
                   ((string=? name "space") #\space)
                   ((string=? name "newline") #\newline)
                   ((string=? name "tab") #\tab)
                   ((string=? name "return") #\return)
                   (else (error 'mobius-read "unknown character name" name))))
                char-value)))

         ;; Datum comment: #;
         ((char=? char #\;)
          (advance port)
          ;; Read and discard next expression
          (mobius-read port)
          ;; Return a sentinel that the caller knows to skip
          'mobius-datum-comment-skip)

         ;; Hash identifier: #true, #false, #nil, #void, #eof, #lang
         (else
          (let ((name (read-collected port
                        (lambda (c)
                          (or (char-alphabetic? c)
                              (digit? c)
                              (char=? c #\-))))))
            (when (string=? name "")
              (error 'mobius-read "empty hash identifier"))
            (cond
             ((string=? name "true") mobius-true)
             ((string=? name "false") mobius-false)
             ((string=? name "nil") mobius-nil)
             ((string=? name "void") mobius-void)
             ((string=? name "eof") mobius-eof)
             ((string=? name "lang")
              ;; Skip the lang name
              (skip-whitespace port)
              (read-collected port (lambda (c) (not (or (whitespace? c) (delimiter? c)))))
              ;; Return sentinel to skip
              'mobius-datum-comment-skip)
             ;; Any other hash-identifier becomes a symbol
             (else
              (string->symbol (string-append "#" name))))))))))

  (define read-identifier
    (lambda (port first-char)
      (let ((rest (read-collected port identifier-continue?)))
        (string->symbol (string-append (string first-char) rest)))))

  ;; --- Pattern reading ---

  ;; When we encounter , in the reader, we produce tagged forms:
  ;; ,x       => (mobius-unquote x)
  ;; ,(x)     => (mobius-unquote-recurse x)
  ;; ,_       => (mobius-unquote _)

  (define read-pattern-unquote
    (lambda (port)
      ;; comma already consumed
      (let ((char (peek port)))
        (cond
         ((eof-object? char)
          (error 'mobius-read "unexpected eof after comma"))
         ((char=? char #\()
          ;; Catamorphic bind: ,(x)
          (advance port)
          (skip-whitespace-and-comments port)
          (let ((identifier (mobius-read port)))
            (skip-whitespace-and-comments port)
            (let ((closing (advance port)))
              (unless (and (not (eof-object? closing))
                           (char=? closing #\)))
                (error 'mobius-read "expected ) after catamorphic bind")))
            (list 'mobius-unquote-recurse identifier)))
         ((char=? char #\_)
          ;; Wildcard: ,_
          (advance port)
          (list 'mobius-unquote '_))
         (else
          ;; Simple bind: ,x
          (let ((identifier (mobius-read port)))
            (list 'mobius-unquote identifier)))))))

  ;; --- List reading ---

  (define read-list
    (lambda (port)
      ;; Opening paren already consumed
      (let loop ((elements '()))
        (skip-whitespace-and-comments port)
        (let ((char (peek port)))
          (cond
           ((eof-object? char)
            (error 'mobius-read "unterminated list"))
           ((char=? char #\))
            (advance port)
            (reverse elements))
           (else
            (let ((element (mobius-read port)))
              (if (eq? element 'mobius-datum-comment-skip)
                  (loop elements)
                  ;; Check for dot notation
                  (if (and (symbol? element) (eq? element 'mobius-dot-sentinel))
                      ;; Dotted pair
                      (let ((tail (mobius-read port)))
                        (skip-whitespace-and-comments port)
                        (let ((closing (advance port)))
                          (unless (and (not (eof-object? closing))
                                       (char=? closing #\)))
                            (error 'mobius-read "expected ) after dotted pair tail")))
                        ;; Build improper list from elements (in reverse order) and tail
                        (let build ((remaining elements)
                                    (accumulator tail))
                          (if (null? remaining)
                              accumulator
                              (build (cdr remaining)
                                     (cons (car remaining) accumulator)))))
                      (loop (cons element elements)))))))))))

  ;; --- Main reader ---

  (define mobius-read
    (lambda (port)
      (skip-whitespace-and-comments port)
      (let ((char (peek port)))
        (cond
         ((eof-object? char) (eof-object))

         ;; String
         ((char=? char #\")
          (advance port)
          (read-string-literal port))

         ;; List
         ((char=? char #\()
          (advance port)
          (read-list port))

         ;; Hash token
         ((char=? char #\#)
          (advance port)
          (let ((result (read-hash-token port)))
            (if (eq? result 'mobius-datum-comment-skip)
                (mobius-read port)
                result)))

         ;; Pattern unquote
         ((char=? char #\,)
          (advance port)
          (read-pattern-unquote port))

         ;; Number or sign-prefixed identifier
         ((digit? char)
          (advance port)
          (read-number port char))

         ((or (char=? char #\+) (char=? char #\-))
          (advance port)
          (let ((next (peek port)))
            (if (and (not (eof-object? next))
                     (or (digit? next) (char=? next #\.)))
                (read-number port char)
                ;; It's an identifier like + or - or +=
                (read-identifier port char))))

         ;; Dot (for dotted pairs inside lists)
         ((char=? char #\.)
          (advance port)
          (let ((next (peek port)))
            (if (and (not (eof-object? next))
                     (digit? next))
                ;; Float starting with .
                (read-number port char)
                ;; Dot symbol for pair notation
                'mobius-dot-sentinel)))

         ;; Identifier
         ((identifier-start? char)
          (advance port)
          (read-identifier port char))

         (else
          (error 'mobius-read "unexpected character" char))))))

  ;; Read all expressions from a port
  (define mobius-read-all
    (lambda (port)
      (let loop ((expressions '()))
        (let ((expression (mobius-read port)))
          (if (eof-object? expression)
              (reverse expressions)
              (loop (cons expression expressions)))))))

  ;; Convenience: read from a string
  (define mobius-read-string
    (lambda (string)
      (let ((port (open-input-string string)))
        (mobius-read port))))

  (define mobius-read-all-string
    (lambda (string)
      (let ((port (open-input-string string)))
        (mobius-read-all port))))

  ;; --- Tests ---

  (define ~check-reader-integers
    (lambda ()
      (assert (= 42 (mobius-read-string "42")))
      (assert (= -7 (mobius-read-string "-7")))
      (assert (= 0 (mobius-read-string "0")))
      (assert (= 3 (mobius-read-string "+3")))))

  (define ~check-reader-hex-integers
    (lambda ()
      (assert (= 255 (mobius-read-string "0xFF")))
      (assert (= 255 (mobius-read-string "0xff")))
      (assert (= #xC0FF33 (mobius-read-string "0xC0FF33")))
      ;; Large hex for capsule type IDs
      (assert (= #x9f3a7b2c (mobius-read-string "0x9f3a7b2c")))))

  (define ~check-reader-floats
    (lambda ()
      (assert (= 3.14 (mobius-read-string "3.14")))
      (assert (= -0.5 (mobius-read-string "-0.5")))
      (assert (= 2.5e-3 (mobius-read-string "2.5e-3")))))

  (define ~check-reader-strings
    (lambda ()
      (assert (equal? "hello" (mobius-read-string "\"hello\"")))
      (assert (equal? "line\nnext" (mobius-read-string "\"line\\nnext\"")))
      (assert (equal? "tab\there" (mobius-read-string "\"tab\\there\"")))
      (assert (equal? "quote\"end" (mobius-read-string "\"quote\\\"end\"")))))

  (define ~check-reader-characters
    (lambda ()
      (assert (char=? #\a (mobius-read-string "#\\a")))
      (assert (char=? #\Z (mobius-read-string "#\\Z")))
      (assert (char=? #\space (mobius-read-string "#\\space")))
      (assert (char=? #\newline (mobius-read-string "#\\newline")))
      (assert (char=? #\tab (mobius-read-string "#\\tab")))))

  (define ~check-reader-hash-identifiers
    (lambda ()
      (assert (eq? mobius-true (mobius-read-string "#true")))
      (assert (eq? mobius-false (mobius-read-string "#false")))
      (assert (eq? mobius-nil (mobius-read-string "#nil")))
      (assert (eq? mobius-void (mobius-read-string "#void")))
      (assert (eq? mobius-eof (mobius-read-string "#eof")))))

  (define ~check-reader-symbols
    (lambda ()
      (assert (eq? 'foo (mobius-read-string "foo")))
      (assert (eq? 'car (mobius-read-string "car")))
      (assert (eq? '+ (mobius-read-string "+")))
      (assert (eq? 'list->string (mobius-read-string "list->string")))
      (assert (eq? 'point? (mobius-read-string "point?")))
      (assert (eq? 'box! (mobius-read-string "box!")))))

  (define ~check-reader-lists
    (lambda ()
      (assert (equal? '(1 2 3) (mobius-read-string "(1 2 3)")))
      (assert (equal? '(+ 1 2) (mobius-read-string "(+ 1 2)")))
      (assert (equal? '(define x 10) (mobius-read-string "(define x 10)")))))

  (define ~check-reader-pairs
    (lambda ()
      (assert (equal? '(1 . 2) (mobius-read-string "(1 . 2)")))
      (assert (equal? '(1 2 . 3) (mobius-read-string "(1 2 . 3)")))))

  (define ~check-reader-patterns
    (lambda ()
      ;; ,x => (mobius-unquote x)
      (assert (equal? '(mobius-unquote x) (mobius-read-string ",x")))
      ;; ,_ => (mobius-unquote _)
      (assert (equal? '(mobius-unquote _) (mobius-read-string ",_")))
      ;; Pattern in list
      (let ((result (mobius-read-string "(,a ,b)")))
        (assert (equal? '((mobius-unquote a) (mobius-unquote b)) result)))))

  (define ~check-reader-catamorphic-patterns
    (lambda ()
      ;; ,(x) => (mobius-unquote-recurse x)
      (assert (equal? '(mobius-unquote-recurse tail)
                       (mobius-read-string ",(tail)")))
      ;; In context
      (let ((result (mobius-read-string "((mobius-unquote head) . (mobius-unquote-recurse tail))")))
        ;; This reads the literal symbols, not pattern syntax
        ;; Pattern syntax is only triggered by bare comma
        (assert (pair? result)))))

  (define ~check-reader-predicate-guard
    (lambda ()
      ;; (? pred ,x) is just a normal list with pattern comma syntax
      (let ((result (mobius-read-string "(? my? ,x)")))
        (assert (equal? '(? my? (mobius-unquote x)) result)))))

  (define ~check-reader-comments
    (lambda ()
      ;; Line comment
      (assert (= 42 (mobius-read-string "; this is a comment\n42")))
      ;; Multiple comments
      (assert (= 7 (mobius-read-string "; first\n; second\n7")))))

  (define ~check-reader-datum-comments
    (lambda ()
      ;; #; comments out next expression
      (assert (= 2 (mobius-read-string "#;1 2")))
      ;; In a list
      (assert (equal? '(1 3) (mobius-read-string "(1 #;2 3)")))))

  (define ~check-reader-nested
    (lambda ()
      (let ((result (mobius-read-string "(define sum (gamma ((,head . ,(tail)) (+ head tail)) (#nil 0)))")))
        (assert (eq? 'define (car result)))
        (assert (eq? 'sum (cadr result)))
        (assert (eq? 'gamma (car (caddr result)))))))

  (define ~check-reader-lang-directive
    (lambda ()
      ;; #lang round is accepted and skipped
      (assert (= 42 (mobius-read-string "#lang round\n42")))
      ;; Multiple expressions after lang
      (let ((result (mobius-read-all-string "#lang round\n(define x 10)\n(define y 20)")))
        (assert (= 2 (length result))))))

  )
