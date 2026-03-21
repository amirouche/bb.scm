(library (bb pattern)

  (export pattern-match
          ~check-pattern-literal
          ~check-pattern-bind
          ~check-pattern-wildcard
          ~check-pattern-pair
          ~check-pattern-list
          ~check-pattern-predicate-guard
          ~check-pattern-catamorphic-bind
          ~check-pattern-nested
          ~check-pattern-no-match)

  (import (chezscheme)
          (bb values))

  ;; Pattern matching for Mobius gamma clauses.
  ;;
  ;; Patterns are represented as parsed reader output:
  ;;   42, "hello", #true, #false, #nil  => literal match
  ;;   (mobius-unquote x)                 => bind to de Bruijn index
  ;;   (mobius-unquote _)                 => wildcard (match, don't bind)
  ;;   (mobius-unquote-recurse x)         => catamorphic bind
  ;;   (? pred (mobius-unquote x))        => predicate guard
  ;;   (pattern1 . pattern2)             => pair destructuring
  ;;
  ;; pattern-match takes:
  ;;   - pattern: the pattern expression
  ;;   - value: the runtime value to match against
  ;;   - self-combiner: the enclosing combiner (for catamorphic binds)
  ;;   - apply-procedure: a procedure (combiner value) -> result
  ;;   - eval-procedure: a procedure (expression env) -> result (for pred guards)
  ;;   - environment: current evaluation environment (for pred guards)
  ;;
  ;; Returns: #f on failure, or a list of (index . value) bindings on success.
  ;; The caller allocates de Bruijn indices to pattern variables.

  ;; We need a counter for de Bruijn index assignment. The pattern
  ;; parser assigns indices starting at 1 (0 is self) in order of
  ;; appearance across all clauses.
  ;;
  ;; This module matches against patterns where indices are already
  ;; assigned. The reader produces (mobius-unquote x) with symbol x;
  ;; the evaluator converts these to (mobius-bind N) or
  ;; (mobius-catamorphic-bind N) before calling pattern-match.

  ;; Match a single pattern against a value.
  ;; Returns #f or list of (index . value) bindings.
  (define pattern-match
    (lambda (pattern value self-combiner apply-procedure
             eval-procedure environment)
      (match-inner pattern value self-combiner
                   apply-procedure eval-procedure environment)))

  (define match-inner
    (lambda (pattern value self-combiner apply-procedure
             eval-procedure environment)
      (cond
       ;; mobius-bind: (mobius-bind N) — bind value at de Bruijn index N
       ((and (pair? pattern)
             (eq? 'mobius-bind (car pattern)))
        (let ((index (cadr pattern)))
          (list (cons index value))))

       ;; mobius-catamorphic-bind: (mobius-catamorphic-bind N)
       ;; Apply self to value, bind result at index N
       ((and (pair? pattern)
             (eq? 'mobius-catamorphic-bind (car pattern)))
        (let ((index (cadr pattern)))
          (let ((result (apply-procedure self-combiner value)))
            (list (cons index result)))))

       ;; mobius-wildcard — match anything, bind nothing
       ((and (pair? pattern)
             (eq? 'mobius-wildcard (car pattern)))
        '())

       ;; Predicate guard: (? pred-expr (mobius-bind N))
       ;; Apply predicate to value; if truthy, bind
       ((and (pair? pattern)
             (eq? '? (car pattern))
             (= 3 (length pattern)))
        (let* ((predicate-expression (cadr pattern))
               (bind-pattern (caddr pattern))
               ;; Evaluate the predicate name in the current environment
               (predicate-value (eval-procedure predicate-expression environment))
               ;; Apply predicate to value
               (test-result (apply-procedure predicate-value (cons value mobius-nil))))
          (if (mobius-truthy? test-result)
              (match-inner bind-pattern value self-combiner
                           apply-procedure eval-procedure environment)
              #f)))

       ;; #nil — match mobius-nil (= '()) exactly
       ((null? pattern)
        (if (null? value)
            '()
            #f))

       ;; Pair pattern — match car and cdr
       ((pair? pattern)
        (if (pair? value)
            (let ((car-bindings
                   (match-inner (car pattern) (car value) self-combiner
                                apply-procedure eval-procedure environment)))
              (if car-bindings
                  (let ((cdr-bindings
                         (match-inner (cdr pattern) (cdr value) self-combiner
                                      apply-procedure eval-procedure environment)))
                    (if cdr-bindings
                        (append car-bindings cdr-bindings)
                        #f))
                  #f))
            #f))

       ;; Literal match — exact equality
       ((or (integer? pattern)
            (flonum? pattern)
            (char? pattern)
            (string? pattern)
            (boolean? pattern))
        (cond
         ((string? pattern) (if (and (string? value) (string=? pattern value)) '() #f))
         ((flonum? pattern) (if (and (flonum? value) (fl=? pattern value)) '() #f))
         (else (if (eqv? pattern value) '() #f))))

       ;; Void, eof singletons
       ((mobius-void? pattern)
        (if (mobius-void? value) '() #f))
       ((mobius-eof? pattern)
        (if (mobius-eof? value) '() #f))

       ;; Unknown pattern
       (else
        (error 'pattern-match "unknown pattern form" pattern)))))

  ;; --- Tests ---

  ;; Helpers for testing. We don't need a full evaluator for basic
  ;; pattern tests — just stubs for apply-procedure and eval-procedure.

  (define stub-apply
    (lambda (combiner value)
      (error 'stub-apply "should not be called")))

  (define stub-eval
    (lambda (expression environment)
      (error 'stub-eval "should not be called")))

  (define ~check-pattern-literal
    (lambda ()
      ;; Integer literal
      (assert (equal? '()
                       (pattern-match 42 42 #f stub-apply stub-eval #f)))
      (assert (not (pattern-match 42 43 #f stub-apply stub-eval #f)))
      ;; String literal
      (assert (equal? '()
                       (pattern-match "hello" "hello" #f stub-apply stub-eval #f)))
      (assert (not (pattern-match "hello" "world" #f stub-apply stub-eval #f)))
      ;; Boolean
      (assert (equal? '()
                       (pattern-match #t #t #f stub-apply stub-eval #f)))
      (assert (not (pattern-match #t #f #f stub-apply stub-eval #f)))))

  (define ~check-pattern-bind
    (lambda ()
      ;; (mobius-bind 1) matches anything and binds at index 1
      (let ((result (pattern-match '(mobius-bind 1) 42 #f stub-apply stub-eval #f)))
        (assert (equal? '((1 . 42)) result)))
      (let ((result (pattern-match '(mobius-bind 1) "hello" #f stub-apply stub-eval #f)))
        (assert (equal? '((1 . "hello")) result)))))

  (define ~check-pattern-wildcard
    (lambda ()
      ;; Wildcard matches anything, produces no bindings
      (assert (equal? '()
                       (pattern-match '(mobius-wildcard) 42 #f stub-apply stub-eval #f)))
      (assert (equal? '()
                       (pattern-match '(mobius-wildcard) "anything" #f stub-apply stub-eval #f)))))

  (define ~check-pattern-pair
    (lambda ()
      ;; Pair pattern: ((mobius-bind 1) . (mobius-bind 2))
      (let ((result (pattern-match
                     (cons '(mobius-bind 1) '(mobius-bind 2))
                     (cons 10 20)
                     #f stub-apply stub-eval #f)))
        (assert (equal? '((1 . 10) (2 . 20)) result)))
      ;; Pair pattern against non-pair
      (assert (not (pattern-match
                    (cons '(mobius-bind 1) '(mobius-bind 2))
                    42
                    #f stub-apply stub-eval #f)))))

  (define ~check-pattern-list
    (lambda ()
      ;; List pattern: ((mobius-bind 1) (mobius-bind 2) . #nil)
      ;; Matches a 2-element mobius list
      (let* ((mobius-list (cons 10 (cons 20 mobius-nil)))
             (pattern (cons '(mobius-bind 1) (cons '(mobius-bind 2) mobius-nil)))
             (result (pattern-match pattern mobius-list #f stub-apply stub-eval #f)))
        (assert (equal? '((1 . 10) (2 . 20)) result)))))

  (define ~check-pattern-predicate-guard
    (lambda ()
      ;; (? integer? (mobius-bind 1))
      ;; apply-procedure receives an argument tree (cons value #nil)
      (let* ((integer-predicate 'int-pred-marker)
             (my-apply (lambda (combiner arg-tree)
                         (if (eq? combiner integer-predicate)
                             (mobius-integer? (car arg-tree))
                             (error 'test "unexpected combiner"))))
             (result (pattern-match
                      '(? integer? (mobius-bind 1))
                      42
                      #f
                      my-apply
                      (lambda (expression environment) integer-predicate)
                      #f)))
        (assert (equal? '((1 . 42)) result)))
      ;; Non-matching predicate: integer? applied to a string returns #f
      (let* ((int-pred2 'int-pred-marker2)
             (my-apply2 (lambda (combiner arg-tree)
                          (if (eq? combiner int-pred2)
                              (mobius-integer? (car arg-tree))
                              (error 'test "unexpected combiner"))))
             (result (pattern-match
                      '(? integer? (mobius-bind 1))
                      "not-an-int"
                      #f
                      my-apply2
                      (lambda (expression environment) int-pred2)
                      #f)))
        (assert (not result)))))

  (define ~check-pattern-catamorphic-bind
    (lambda ()
      ;; (mobius-catamorphic-bind 2) — apply self to subtree
      ;; Use a fake self combiner that doubles the value
      (let* ((fake-self 'self-marker)
             (fake-apply (lambda (combiner value)
                           (assert (eq? combiner fake-self))
                           (* value 2)))
             (result (pattern-match
                      '(mobius-catamorphic-bind 2)
                      5
                      fake-self
                      fake-apply
                      stub-eval
                      #f)))
        (assert (equal? '((2 . 10)) result)))))

  (define ~check-pattern-nested
    (lambda ()
      ;; Nested pair: ((mobius-bind 1) . ((mobius-bind 2) . (mobius-bind 3)))
      ;; Matches (a b . c)
      (let* ((pattern (cons '(mobius-bind 1)
                            (cons '(mobius-bind 2)
                                  '(mobius-bind 3))))
             (value (cons 'x (cons 'y 'z)))
             (result (pattern-match pattern value #f stub-apply stub-eval #f)))
        (assert (equal? '((1 . x) (2 . y) (3 . z)) result)))))

  (define ~check-pattern-no-match
    (lambda ()
      ;; Literal mismatch
      (assert (not (pattern-match 42 99 #f stub-apply stub-eval #f)))
      ;; Pair pattern against atom
      (assert (not (pattern-match
                    (cons '(mobius-bind 1) '(mobius-bind 2))
                    42
                    #f stub-apply stub-eval #f)))
      ;; #nil pattern against non-nil
      (assert (not (pattern-match mobius-nil 42 #f stub-apply stub-eval #f)))))

  )
