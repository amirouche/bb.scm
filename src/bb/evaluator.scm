(library (bb evaluator)

  (export mobius-eval
          mobius-apply
          mobius-eval-top-level
          make-initial-environment
          name-environment-extend
          name-environment-ref
          name-environment-set!
          build-argument-tree
          normalize-combiner
          denormalize-tree
          ~check-evaluator-atoms
          ~check-evaluator-if
          ~check-evaluator-and-or
          ~check-evaluator-begin
          ~check-evaluator-define-nested
          ~check-evaluator-lambda
          ~check-evaluator-gamma
          ~check-evaluator-gamma-catamorphic
          ~check-evaluator-cons-car-cdr
          ~check-evaluator-arithmetic
          ~check-evaluator-predicates
          ~check-evaluator-comparison
          ~check-evaluator-box
          ~check-evaluator-encapsulation
          ~check-evaluator-call-cc
          ~check-evaluator-display
          ~check-evaluator-eq
          ~check-evaluator-factorial
          ~check-evaluator-assume
          ~check-evaluator-xeno
          ~check-evaluator-string-literal
          ~check-normalize-sum
          ~check-normalize-factorial
          ~check-normalize-same-hash
          ~check-evaluator-mutual-recursion
          ~check-denormalize-lambda-round-trip
          ~check-denormalize-gamma-round-trip)

  (import (chezscheme)
          (bb match)
          (bb values)
          (bb environment)
          (bb pattern)
          (bb reader))

  ;; ================================================================
  ;; Mobius Seed Evaluator — tree-walking interpreter
  ;;
  ;; Evaluates Mobius round-surface expressions. The environment is
  ;; a name-based lookup (symbols to values) for the surface evaluator.
  ;; Content-addressed de Bruijn evaluation is used for stored
  ;; combiners; the surface evaluator works with named variables.
  ;;
  ;; The evaluator handles:
  ;; - Self-evaluating atoms (integers, floats, chars, strings, booleans, #nil, #void, #eof)
  ;; - Symbol lookup in environment
  ;; - Special forms: gamma, lambda, if, and, or, begin, define, guard
  ;; - Application: (f args...) => build argument tree, apply
  ;; - Pattern matching for gamma clauses
  ;; ================================================================

  ;; We use a name-based environment for the surface evaluator.
  ;; This is a simple alist of (symbol . value) pairs.

  (define name-environment-empty
    (lambda ()
      '()))

  (define name-environment-extend
    (lambda (environment name value)
      (cons (cons name value) environment)))

  (define name-environment-extend*
    (lambda (environment pairs)
      (append pairs environment)))

  (define name-environment-ref
    (lambda (environment name)
      (let ((binding (assq name environment)))
        (if binding
            (cdr binding)
            (error 'mobius-eval "unbound variable" name)))))

  (define name-environment-has?
    (lambda (environment name)
      (if (assq name environment) #t #f)))

  (define name-environment-set!
    (lambda (environment name value)
      ;; Returns a new environment with the binding updated
      ;; For mutable nested defines, we use boxes
      (let loop ((current environment))
        (cond
         ((null? current)
          (error 'name-environment-set! "variable not found" name))
         ((eq? name (caar current))
          (set-cdr! (car current) value)
          environment)
         (else
          (loop (cdr current)))))))

  ;; ================================================================
  ;; Self-evaluating check
  ;; ================================================================

  (define self-evaluating?
    (lambda (expression)
      (or (mobius-integer? expression)
          (mobius-float? expression)
          (mobius-char? expression)
          (mobius-string? expression)
          (boolean? expression)
          (mobius-nil? expression)
          (mobius-void? expression)
          (mobius-eof? expression))))

  ;; ================================================================
  ;; Pattern processing for gamma/lambda
  ;; ================================================================

  ;; Convert a surface pattern (with ,x syntax) to internal form
  ;; with (mobius-bind N) nodes. Returns (internal-pattern . name-list)
  ;; where name-list is the list of bound names in order.
  ;;
  ;; Index 0 is reserved for self. Pattern variables get indices
  ;; starting at 1.

  (define process-pattern
    (lambda (pattern next-index)
      ;; Returns (values internal-pattern next-index name-alist)
      ;; name-alist is ((name . index) ...)
      (cond
       ;; (mobius-unquote x) => (mobius-bind N)
       ((and (pair? pattern)
             (eq? 'mobius-unquote (car pattern)))
        (let ((name (cadr pattern)))
          (if (eq? name '_)
              ;; Wildcard
              (values '(mobius-wildcard) next-index '())
              ;; Named bind
              (values (list 'mobius-bind next-index)
                      (+ next-index 1)
                      (list (cons name next-index))))))

       ;; (mobius-unquote-recurse x) => (mobius-catamorphic-bind N)
       ((and (pair? pattern)
             (eq? 'mobius-unquote-recurse (car pattern)))
        (let ((name (cadr pattern)))
          (values (list 'mobius-catamorphic-bind next-index)
                  (+ next-index 1)
                  (list (cons name next-index)))))

       ;; Pair pattern
       ((pair? pattern)
        (let-values (((car-internal car-next car-names)
                      (process-pattern (car pattern) next-index)))
          (let-values (((cdr-internal cdr-next cdr-names)
                        (process-pattern (cdr pattern) car-next)))
            (values (cons car-internal cdr-internal)
                    cdr-next
                    (append car-names cdr-names)))))

       ;; Scheme null — reader produces () for end of list patterns
       ((null? pattern)
        (values '() next-index '()))

       ;; Literal or #nil — pass through
       (else
        (values pattern next-index '())))))

  ;; Process all clauses for a gamma. Returns list of
  ;; (internal-pattern body name-alist) triples and the final next-index.
  (define process-gamma-clauses
    (lambda (clauses)
      (let loop ((remaining clauses)
                 (next-index 1)
                 (processed '()))
        (if (null? remaining)
            (reverse processed)
            (let* ((clause (car remaining))
                   (pattern (car clause))
                   (body (cadr clause)))
              (let-values (((internal next names)
                            (process-pattern pattern next-index)))
                (loop (cdr remaining)
                      next
                      (cons (list internal body names) processed))))))))

  ;; ================================================================
  ;; Application
  ;; ================================================================

  ;; Build argument tree from evaluated arguments: (v1 v2 v3) =>
  ;; (cons v1 (cons v2 (cons v3 #nil)))
  (define build-argument-tree
    (lambda (values-list)
      (let loop ((remaining values-list))
        (if (null? remaining)
            mobius-nil
            (cons (car remaining) (loop (cdr remaining)))))))

  ;; Apply a combiner to an argument tree
  (define mobius-apply
    (lambda (combiner argument-tree environment)
      (cond
       ;; Native combiner (Scheme closure wrapper)
       ((native-combiner? combiner)
        ((<native-combiner>-procedure combiner) argument-tree))

       ;; Primitive combiner
       ((mobius-primitive? combiner)
        (apply-primitive combiner argument-tree environment))

       ;; User-defined combiner (gamma/lambda closure)
       ((mobius-user-combiner? combiner)
        (apply-user-combiner combiner argument-tree))

       ;; Continuation — unwrap single-argument tree
       ((mobius-continuation? combiner)
        ((mobius-continuation-procedure combiner) (car argument-tree)))

       (else
        (error 'mobius-apply "not a combiner" combiner)))))

  (define apply-user-combiner
    (lambda (combiner argument-tree)
      (let* ((clauses (mobius-combiner-clauses combiner))
             (closure-environment (mobius-combiner-environment combiner)))
        (let loop ((remaining clauses))
          (if (null? remaining)
              (error 'mobius-apply "no matching clause"
                     (mobius-combiner-name combiner) argument-tree)
              (let* ((clause (car remaining))
                     (internal-pattern (car clause))
                     (body (cadr clause))
                     (name-alist (caddr clause))
                     (bindings (pattern-match
                                internal-pattern
                                argument-tree
                                combiner
                                (lambda (c v) (mobius-apply c v closure-environment))
                                (lambda (e environment) (mobius-eval e environment))
                                closure-environment)))
                (if bindings
                    ;; Build environment with bindings
                    (let* ((binding-environment
                            (let bind-loop ((names name-alist)
                                            (environment closure-environment))
                              (if (null? names)
                                  environment
                                  (let* ((name (caar names))
                                         (index (cdar names))
                                         (value (let ((found (assv index bindings)))
                                                  (if found (cdr found)
                                                      (error 'apply "missing binding" index)))))
                                    (bind-loop (cdr names)
                                               (name-environment-extend environment name value))))))
                           ;; Self reference at the combiner's own name
                           (full-environment
                            (let ((name (mobius-combiner-name combiner)))
                              (if name
                                  (name-environment-extend binding-environment name combiner)
                                  binding-environment))))
                      (mobius-eval body full-environment))
                    (loop (cdr remaining)))))))))

  ;; ================================================================
  ;; Primitive application (foundations 0-34)
  ;; ================================================================

  (define apply-primitive
    (lambda (primitive argument-tree environment)
      (let ((index (mobius-primitive-index primitive))
            (arguments (mobius-list->scheme-list argument-tree)))
        (case index
          ;; 8: cons
          ((8) (cons (car arguments) (cadr arguments)))
          ;; 9: car
          ((9)
           (let ((value (car arguments)))
             (if (pair? value)
                 (car value)
                 (error 'car "not a pair" value))))
          ;; 10: cdr
          ((10)
           (let ((value (car arguments)))
             (if (pair? value)
                 (cdr value)
                 (error 'cdr "not a pair" value))))
          ;; 11: encapsulation-type
          ((11)
           (let ((type-id (car arguments)))
             (let* ((constructor
                     (make-mobius-primitive -1
                       (string-append "capsule-constructor-" (number->string type-id))))
                    (predicate
                     (make-mobius-primitive -2
                       (string-append "capsule-predicate-" (number->string type-id))))
                    (accessor
                     (make-mobius-primitive -3
                       (string-append "capsule-accessor-" (number->string type-id)))))
               ;; We return a tree (constructor predicate accessor)
               ;; But we need actual closures. Use lambda captures.
               (let ((make-constructor
                      (lambda (arg-tree)
                        (make-mobius-capsule type-id (car (mobius-list->scheme-list arg-tree)))))
                     (make-predicate
                      (lambda (arg-tree)
                        (let ((value (car (mobius-list->scheme-list arg-tree))))
                          (if (and (mobius-capsule? value)
                                   (= type-id (mobius-capsule-type-id value)))
                              #t #f))))
                     (make-accessor
                      (lambda (arg-tree)
                        (let ((value (car (mobius-list->scheme-list arg-tree))))
                          (if (and (mobius-capsule? value)
                                   (= type-id (mobius-capsule-type-id value)))
                              (mobius-capsule-value value)
                              (error 'capsule-accessor "wrong type" type-id value))))))
                 ;; Return as Mobius list: (constructor . (predicate . (accessor . #nil)))
                 (cons (make-mobius-closure make-constructor "capsule-constructor")
                       (cons (make-mobius-closure make-predicate "capsule-predicate")
                             (cons (make-mobius-closure make-accessor "capsule-accessor")
                                   mobius-nil)))))))
          ;; 12: box
          ((12) (make-mobius-box (car arguments)))
          ;; 13: unbox
          ((13)
           (let ((value (car arguments)))
             (if (mobius-box? value)
                 (mobius-box-ref value)
                 (error 'unbox "not a box" value))))
          ;; 14: box!
          ((14)
           (let ((box-value (car arguments))
                 (new-value (cadr arguments)))
             (if (mobius-box? box-value)
                 (begin (mobius-box-set! box-value new-value) mobius-void)
                 (error 'box! "not a box" box-value))))
          ;; 15: call/cc
          ((15)
           (let ((combiner (car arguments)))
             (call/cc
              (lambda (k)
                (let ((mobius-k (make-mobius-continuation
                                 (lambda (value) (k value)))))
                  (mobius-apply combiner
                               (build-argument-tree (list mobius-k))
                               environment))))))
          ;; 16: continuation-apply
          ((16)
           (let ((continuation (car arguments))
                 (value (cadr arguments)))
             (if (mobius-continuation? continuation)
                 ((mobius-continuation-procedure continuation) value)
                 (error 'continuation-apply "not a continuation" continuation))))
          ;; 17-24: type predicates
          ((17) (if (mobius-integer? (car arguments)) #t #f))
          ((18) (if (mobius-float? (car arguments)) #t #f))
          ((19) (if (mobius-char? (car arguments)) #t #f))
          ((20) (if (mobius-string? (car arguments)) #t #f))
          ((21) (if (mobius-pair? (car arguments)) #t #f))
          ((22) (if (mobius-box? (car arguments)) #t #f))
          ((23) (if (or (mobius-combiner? (car arguments))
                        (native-combiner? (car arguments))) #t #f))
          ((24) (if (mobius-continuation? (car arguments)) #t #f))
          ;; 25: eq?
          ((25)
           (let ((a (car arguments)) (b (cadr arguments)))
             (if (eq? a b) #t #f)))
          ;; 26-29: arithmetic
          ((26) (apply + arguments))   ;; +
          ((27) (apply - arguments))   ;; -
          ((28) (apply * arguments))   ;; *
          ((29)                   ;; /
           (let ((a (car arguments)) (b (cadr arguments)))
             (when (zero? b) (error '/ "division by zero"))
             (/ a b)))
          ;; 30-32: comparison
          ((30) (if (< (car arguments) (cadr arguments)) #t #f))   ;; <
          ((31) (if (> (car arguments) (cadr arguments)) #t #f))   ;; >
          ((32) (if (= (car arguments) (cadr arguments)) #t #f))   ;; =
          ;; 33: display
          ((33)
           (let ((value (car arguments)))
             (mobius-display value)
             mobius-void))
          ;; 34: assume (runtime assertion)
          ((34)
           (let ((test (car arguments))
                 (message (if (> (length arguments) 1) (cadr arguments) "assertion failed")))
             (if (mobius-truthy? test)
                 #t
                 (error 'assume
                        (if (string? message) message "assertion failed")
                        test))))
          ;; 35: xeno (foreign function call to Chez Scheme)
          ((35)
           (let ((procedure-name (car arguments))
                 (procedure-arguments (cdr arguments)))
             (unless (string? procedure-name)
               (error 'xeno "first argument must be a string" procedure-name))
             (let ((procedure (eval (string->symbol procedure-name))))
               (apply procedure (mobius-list->scheme-list
                            (build-argument-tree procedure-arguments))))))
          (else
           (error 'apply-primitive "unknown primitive index" index))))))

  ;; Native combiner: wraps a Scheme procedure as a Mobius combiner
  (define-record-type <native-combiner>
    (nongenerative native-combiner-8f2a3c1d)
    (fields procedure name)
    (protocol (lambda (new) (lambda (procedure name) (new procedure name)))))

  (define native-combiner?
    (lambda (value) (<native-combiner>? value)))

  (define make-mobius-closure
    (lambda (procedure name)
      (make-<native-combiner> procedure name)))

  ;; ================================================================
  ;; Display
  ;; ================================================================

  (define mobius-display
    (lambda (value)
      (cond
       ((mobius-nil? value) (display "#nil"))
       ((mobius-void? value) (display "#void"))
       ((mobius-eof? value) (display "#eof"))
       ((boolean? value) (display (if value "#true" "#false")))
       ((string? value) (display value))
       ((char? value) (display value))
       ((integer? value) (display value))
       ((flonum? value) (display value))
       ((pair? value)
        (display "(")
        (mobius-display (car value))
        (let loop ((tail (cdr value)))
          (cond
           ((mobius-nil? tail) (display ")"))
           ((pair? tail)
            (display " ")
            (mobius-display (car tail))
            (loop (cdr tail)))
           (else
            (display " . ")
            (mobius-display tail)
            (display ")")))))
       ((mobius-box? value)
        (display "#<box ")
        (mobius-display (mobius-box-ref value))
        (display ">"))
       ((mobius-capsule? value)
        (display "#<capsule ")
        (display (mobius-capsule-type-id value))
        (display ">"))
       ((mobius-user-combiner? value)
        (display "#<combiner")
        (when (mobius-combiner-name value)
          (display " ")
          (display (mobius-combiner-name value)))
        (display ">"))
       ((mobius-primitive? value)
        (display "#<primitive ")
        (display (mobius-primitive-name value))
        (display ">"))
       ((<native-combiner>? value)
        (display "#<native ")
        (display (<native-combiner>-name value))
        (display ">"))
       ((mobius-continuation? value)
        (display "#<continuation>"))
       (else
        (display "#<unknown>")))))

  ;; ================================================================
  ;; Evaluator
  ;; ================================================================

  (define mobius-eval
    (lambda (expression environment)
      (cond
       ;; Self-evaluating
       ((self-evaluating? expression)
        expression)

       ;; Symbol lookup
       ((symbol? expression)
        (name-environment-ref environment expression))

       ;; Special forms and application
       ((pair? expression)
        (let ((head (car expression)))
          (cond
           ;; (gamma clause ...)
           ((eq? head 'gamma)
            (eval-gamma (cdr expression) environment))

           ;; (lambda (parameters ...) body)
           ((eq? head 'lambda)
            (eval-lambda (cadr expression) (cddr expression) environment))

           ;; (if test then else)
           ((eq? head 'if)
            (eval-if (cadr expression) (caddr expression)
                     (if (null? (cdddr expression)) mobius-void (cadddr expression))
                     environment))

           ;; (and expressions ...)
           ((eq? head 'and)
            (eval-and (cdr expression) environment))

           ;; (or expressions ...)
           ((eq? head 'or)
            (eval-or (cdr expression) environment))

           ;; (begin expressions ...)
           ((eq? head 'begin)
            (eval-begin (cdr expression) environment))

           ;; (define name expression)
           ((eq? head 'define)
            (eval-define (cadr expression) (caddr expression) environment))

           ;; (guard (entry clauses) thunk (exit clauses))
           ((eq? head 'guard)
            (eval-guard (cdr expression) environment))

           ;; Application: (f arguments ...)
           (else
            (eval-application head (cdr expression) environment)))))

       (else
        (error 'mobius-eval "cannot evaluate" expression)))))

  ;; --- Special form implementations ---

  (define eval-gamma
    (lambda (raw-clauses environment)
      ;; raw-clauses is ((pattern body) (pattern body) ...)
      (let ((processed (process-gamma-clauses raw-clauses)))
        (make-mobius-combiner processed environment #f))))

  (define eval-lambda
    (lambda (parameters body-expressions environment)
      ;; (lambda (a b c) body) => gamma with single clause
      ;; Pattern: (,a ,b ,c) => ((mobius-bind 1) (mobius-bind 2) (mobius-bind 3) . #nil)
      ;; Build pattern
      (let* ((name-alist
              (let loop ((parameters parameters)
                         (index 1)
                         (alist '()))
                (if (null? parameters)
                    (reverse alist)
                    (loop (cdr parameters)
                          (+ index 1)
                          (cons (cons (car parameters) index) alist)))))
             (internal-pattern
              (let loop ((parameters parameters)
                         (index 1))
                (if (null? parameters)
                    mobius-nil
                    (cons (list 'mobius-bind index)
                          (loop (cdr parameters) (+ index 1))))))
             (body (if (= 1 (length body-expressions))
                       (car body-expressions)
                       (cons 'begin body-expressions)))
             (clause (list internal-pattern body name-alist)))
        (make-mobius-combiner (list clause) environment #f))))

  (define eval-if
    (lambda (test-expression then-expression else-expression environment)
      (let ((test-value (mobius-eval test-expression environment)))
        (if (mobius-truthy? test-value)
            (mobius-eval then-expression environment)
            (mobius-eval else-expression environment)))))

  (define eval-and
    (lambda (expressions environment)
      (if (null? expressions)
          #t
          (let loop ((remaining expressions))
            (let ((value (mobius-eval (car remaining) environment)))
              (cond
               ((null? (cdr remaining)) value)
               ((not (mobius-truthy? value)) #f)
               (else (loop (cdr remaining)))))))))

  (define eval-or
    (lambda (expressions environment)
      (if (null? expressions)
          #f
          (let loop ((remaining expressions))
            (let ((value (mobius-eval (car remaining) environment)))
              (cond
               ((null? (cdr remaining)) value)
               ((mobius-truthy? value) value)
               (else (loop (cdr remaining)))))))))

  (define eval-begin
    (lambda (expressions environment)
      ;; Pre-bind all define names to allow mutual recursion.
      ;; First pass: extend environment with all define names bound to #void.
      ;; Second pass: evaluate and update bindings in place.
      (let ((define-names
             (filter (lambda (x) x)
                     (map (lambda (expression)
                            (if (and (pair? expression)
                                     (eq? 'define (car expression)))
                                (cadr expression)
                                #f))
                          expressions))))
        ;; Pre-bind all names
        (for-each
         (lambda (name)
           (set! environment (name-environment-extend environment name mobius-void)))
         define-names)
        ;; Evaluate sequentially
        (let loop ((remaining expressions)
                   (last-value mobius-void))
          (if (null? remaining)
              last-value
              (let ((expression (car remaining)))
                (if (and (pair? expression)
                         (eq? 'define (car expression)))
                    ;; Nested define: evaluate and update binding
                    (let* ((name (cadr expression))
                           (value (mobius-eval (caddr expression) environment))
                           ;; If combiner without name, recreate with name for self-reference
                           (value (if (and (mobius-user-combiner? value)
                                           (not (mobius-combiner-name value)))
                                      (make-mobius-combiner
                                       (mobius-combiner-clauses value)
                                       (mobius-combiner-environment value)
                                       name)
                                      value)))
                      ;; Update the pre-bound slot
                      (name-environment-set! environment name value)
                      (loop (cdr remaining) mobius-void))
                    (loop (cdr remaining)
                          (mobius-eval expression environment)))))))))

  (define eval-define
    (lambda (name expression environment)
      ;; Top-level define: evaluate and bind
      (let ((value (mobius-eval expression environment)))
        ;; For top-level, we return a binding pair for the caller to handle
        (cons name value))))

  (define eval-guard
    (lambda (parts environment)
      ;; (guard (entry (pattern handler) ...) thunk (exit (pattern handler) ...))
      ;; Simplified implementation using call/cc
      (let* ((entry-clauses (cdr (car parts)))       ;; skip 'entry symbol
             (thunk-expression (cadr parts))
             (exit-clauses (if (> (length parts) 2)
                               (cdr (caddr parts))   ;; skip 'exit symbol
                               '())))
        ;; Evaluate thunk in a guarded context
        (call/cc
         (lambda (exit-continuation)
           (let ((result
                  (call/cc
                   (lambda (entry-continuation)
                     ;; Install guard boundary
                     (let* ((guard-environment
                             (name-environment-extend environment 'current-guard-entry
                               (make-mobius-continuation
                                (lambda (value)
                                  (entry-continuation value))))))
                       ;; Evaluate the thunk
                       (mobius-eval thunk-expression guard-environment))))))
             ;; If we got here via entry continuation, match entry clauses
             result))))))

  (define eval-application
    (lambda (head-expression argument-expressions environment)
      (let* ((combiner (mobius-eval head-expression environment))
             (argument-values
              (map (lambda (expression) (mobius-eval expression environment))
                   argument-expressions))
             (argument-tree (build-argument-tree argument-values)))
        (mobius-apply combiner argument-tree environment))))

  ;; ================================================================
  ;; Top-level evaluation
  ;; ================================================================

  ;; Evaluate a list of top-level expressions, returning the final
  ;; environment. Handles define at top level.
  (define mobius-eval-top-level
    (lambda (expressions environment)
      ;; Pre-bind all define names to allow mutual recursion
      (let ((define-names
             (filter (lambda (x) x)
                     (map (lambda (expression)
                            (if (and (pair? expression)
                                     (eq? 'define (car expression)))
                                (cadr expression)
                                #f))
                          expressions))))
        (for-each
         (lambda (name)
           (set! environment (name-environment-extend environment name mobius-void)))
         define-names)
        (let loop ((remaining expressions)
                   (last-value mobius-void))
          (if (null? remaining)
              (values environment last-value)
              (let ((expression (car remaining)))
                (if (and (pair? expression)
                         (eq? 'define (car expression)))
                    (let* ((name (cadr expression))
                           (value (mobius-eval (caddr expression) environment))
                           (value (if (and (mobius-user-combiner? value)
                                           (not (mobius-combiner-name value)))
                                      (make-mobius-combiner
                                       (mobius-combiner-clauses value)
                                       (mobius-combiner-environment value)
                                       name)
                                      value)))
                      (name-environment-set! environment name value)
                      (loop (cdr remaining) mobius-void))
                    (loop (cdr remaining)
                          (mobius-eval expression environment)))))))))

  ;; ================================================================
  ;; Initial environment with all 36 primitives
  ;; ================================================================

  (define primitive-names
    '#("gamma" "lambda" "if" "and" "or" "begin" "define" "guard"
       "cons" "car" "cdr" "encapsulation-type" "box" "unbox" "box!"
       "call/cc" "continuation-apply"
       "integer?" "float?" "char?" "string?" "pair?" "box?"
       "combiner?" "continuation?"
       "eq?" "+" "-" "*" "/" "<" ">" "="
       "display"
       "assume"
       "xeno"))

  (define make-initial-environment
    (lambda ()
      (let loop ((index 8) ;; primitives 0-7 are special forms, not values
                 (environment (name-environment-empty)))
        (if (> index 35)
            ;; Add well-known bindings
            (let* ((environment (name-environment-extend environment (string->symbol "#true") #t))
                   (environment (name-environment-extend environment (string->symbol "#false") #f))
                   (environment (name-environment-extend environment (string->symbol "#nil") mobius-nil))
                   (environment (name-environment-extend environment (string->symbol "#void") mobius-void))
                   (environment (name-environment-extend environment (string->symbol "#eof") mobius-eof))
                   ;; continuation-exit: root continuation
                   (environment (name-environment-extend environment 'continuation-exit
                          (make-mobius-continuation
                           (lambda (value)
                             (exit (if (integer? value) value 1)))))))
              environment)
            (let* ((name (string->symbol (vector-ref primitive-names index)))
                   (primitive (make-mobius-primitive index
                                (vector-ref primitive-names index))))
              (loop (+ index 1)
                    (name-environment-extend environment name primitive)))))))

  ;; ================================================================
  ;; De Bruijn Normalization
  ;;
  ;; Converts surface expressions (with named variables) to the
  ;; content-addressed tree form for storage. Variable names are
  ;; erased to de Bruijn indices. Primitives become
  ;; (mobius-primitive-ref N), registered combiners become
  ;; (mobius-constant-ref "hash"), and variables become
  ;; (mobius-variable N).
  ;; ================================================================

  ;; Build a lookup table from primitive name symbols to their indices
  (define primitive-name->index
    (let ((table (make-eq-hashtable)))
      (do ((i 0 (+ i 1)))
        ((= i (vector-length primitive-names)) table)
        (hashtable-set! table
                        (string->symbol (vector-ref primitive-names i))
                        i))))

  ;; Normalize a body expression to de Bruijn form.
  ;; - expression: parsed expression
  ;; - variable-environment: alist of (symbol . index) for bound variables
  ;; - registry-lookup: procedure (symbol -> string-or-#f)
  (define normalize-body
    (lambda (expression variable-environment registry-lookup)
      (cond
       ;; Self-evaluating atoms: sentinels become (mobius-primitive-constant-ref N)
       ((self-evaluating? expression)
        (let ((constant-index (primitive-constant-index expression)))
          (if constant-index
              (list 'mobius-primitive-constant-ref constant-index)
              expression)))

       ;; Symbol: check variable-environment, then primitives, then registry
       ((symbol? expression)
        (let ((var-binding (assq expression variable-environment)))
          (if var-binding
              (if (eq? 'define-local (cdr var-binding))
                  ;; Internal define — keep as raw symbol for runtime binding
                  expression
                  (list 'mobius-variable (cdr var-binding)))
              (let ((prim-index (hashtable-ref primitive-name->index expression #f)))
                (if prim-index
                    (list 'mobius-primitive-ref prim-index)
                    (let ((hash (registry-lookup expression)))
                      (if hash
                          (list 'mobius-constant-ref hash)
                          (error 'normalize "unbound variable" expression))))))))

       ;; Special forms
       ((pair? expression)
        (let ((head (car expression)))
          (cond
           ;; (if test then else)
           ((eq? head 'if)
            (let ((test (normalize-body (cadr expression) variable-environment registry-lookup))
                  (then (normalize-body (caddr expression) variable-environment registry-lookup))
                  (else-expression (if (null? (cdddr expression))
                                 '(mobius-primitive-constant-ref 3)
                                 (normalize-body (cadddr expression) variable-environment registry-lookup))))
              (list '(mobius-primitive-ref 2) test then else-expression)))

           ;; (and expressions ...)
           ((eq? head 'and)
            (cons '(mobius-primitive-ref 3)
                  (map (lambda (e) (normalize-body e variable-environment registry-lookup))
                       (cdr expression))))

           ;; (or expressions ...)
           ((eq? head 'or)
            (cons '(mobius-primitive-ref 4)
                  (map (lambda (e) (normalize-body e variable-environment registry-lookup))
                       (cdr expression))))

           ;; (begin expressions ...)
           ;; Pre-scan for internal defines and add names to variable-environment
           ;; with a 'define-local marker so references stay as raw symbols
           ;; (the evaluator handles define bindings by name at runtime).
           ((eq? head 'begin)
            (let* ((body-expressions (cdr expression))
                   ;; Collect names from internal defines
                   (define-names
                    (filter symbol?
                            (map (lambda (e)
                                   (and (pair? e) (eq? 'define (car e))
                                        (cadr e)))
                                 body-expressions)))
                   ;; Mark define names so the symbol handler emits them as-is
                   (extended-environment
                    (append (map (lambda (n) (cons n 'define-local)) define-names)
                            variable-environment)))
              (cons '(mobius-primitive-ref 5)
                    (map (lambda (e) (normalize-body e extended-environment registry-lookup))
                         body-expressions))))

           ;; (define name expression) inside body
           ((eq? head 'define)
            (list '(mobius-primitive-ref 6)
                  (cadr expression)
                  (normalize-body (caddr expression) variable-environment registry-lookup)))

           ;; (guard ...) — pass through for now
           ((eq? head 'guard)
            (cons '(mobius-primitive-ref 7)
                  (map (lambda (e) (normalize-body e variable-environment registry-lookup))
                       (cdr expression))))

           ;; Nested gamma/lambda — normalize as nested combiner
           ((eq? head 'gamma)
            (let ((processed (process-gamma-clauses (cdr expression))))
              (let* ((all-names (apply append (map caddr processed)))
                     (inner-variable-environment (append all-names variable-environment))
                     (normalized-clauses
                      (map (lambda (clause)
                             (let ((pattern (car clause))
                                   (body (cadr clause)))
                               (list pattern
                                     (normalize-body body inner-variable-environment registry-lookup))))
                           processed)))
                (cons '(mobius-primitive-ref 0) normalized-clauses))))

           ((eq? head 'lambda)
            (let* ((parameters (cadr expression))
                   (body-expressions (cddr expression))
                   (name-alist
                    (let loop ((parameters parameters) (index 1) (alist '()))
                      (if (null? parameters)
                          (reverse alist)
                          (loop (cdr parameters) (+ index 1)
                                (cons (cons (car parameters) index) alist)))))
                   (pattern
                    (let loop ((parameters parameters) (index 1))
                      (if (null? parameters)
                          '()
                          (cons (list 'mobius-bind index)
                                (loop (cdr parameters) (+ index 1))))))
                   (body (if (= 1 (length body-expressions))
                             (car body-expressions)
                             (cons 'begin body-expressions)))
                   (inner-variable-environment (append name-alist variable-environment))
                   (normalized-body (normalize-body body inner-variable-environment registry-lookup)))
              (list '(mobius-primitive-ref 1) pattern normalized-body)))

           ;; Application: (f arguments ...)
           (else
            (let ((normalized-head (normalize-body head variable-environment registry-lookup))
                  (normalized-arguments (map (lambda (e)
                                          (normalize-body e variable-environment registry-lookup))
                                        (cdr expression))))
              (cons normalized-head normalized-arguments))))))

       (else
        (error 'normalize-body "unknown expression" expression)))))

  ;; Normalize a combiner expression.
  ;; - expression: the parsed source expression (e.g. (gamma ...) or (lambda ...))
  ;; - self-name: the symbol this combiner is being defined as (for self-reference)
  ;; - registry-lookup: a procedure (symbol -> string-or-#f) mapping names to hashes
  ;;
  ;; Returns: (values normalized-tree name-alist)
  ;; where name-alist is ((index . "name") ...) for the mapping file.
  (define normalize-combiner
    (lambda (expression self-name registry-lookup)
      (define (normalize-gamma)
        (let ((processed (process-gamma-clauses (cdr expression))))
          (let* ((all-names (apply append (map caddr processed)))
                 (variable-environment (cons (cons self-name 0) all-names))
                 (normalized-clauses
                  (map (lambda (clause)
                         (let ((pattern (car clause))
                               (body (cadr clause)))
                           (list pattern
                                 (normalize-body body variable-environment registry-lookup))))
                       processed))
                 (mapping (cons (cons 0 (symbol->string self-name))
                                (map (lambda (pair)
                                       (cons (cdr pair)
                                             (symbol->string (car pair))))
                                     all-names))))
            (values (cons '(mobius-primitive-ref 0) normalized-clauses)
                    mapping))))
      (define (normalize-lambda)
        (let* ((parameters (cadr expression))
               (body-expressions (cddr expression))
               (name-alist
                (let loop ((parameters parameters) (index 1) (alist '()))
                  (if (null? parameters)
                      (reverse alist)
                      (loop (cdr parameters) (+ index 1)
                            (cons (cons (car parameters) index) alist)))))
               (pattern
                (let loop ((parameters parameters) (index 1))
                  (if (null? parameters)
                      '()
                      (cons (list 'mobius-bind index)
                            (loop (cdr parameters) (+ index 1))))))
               (body (if (= 1 (length body-expressions))
                         (car body-expressions)
                         (cons 'begin body-expressions)))
               (variable-environment (cons (cons self-name 0) name-alist))
               (normalized-body (normalize-body body variable-environment registry-lookup))
               (mapping (cons (cons 0 (symbol->string self-name))
                              (map (lambda (pair)
                                     (cons (cdr pair)
                                           (symbol->string (car pair))))
                                   name-alist))))
          (values (list '(mobius-primitive-ref 1)
                        pattern
                        normalized-body)
                  mapping)))
      (if (and (pair? expression) (eq? 'gamma (car expression)))
          (normalize-gamma)
          (if (and (pair? expression) (eq? 'lambda (car expression)))
              (normalize-lambda)
              (error 'normalize-combiner "expected gamma or lambda" expression)))))

  ;; ================================================================
  ;; Denormalization — convert stored de Bruijn tree back to surface
  ;; syntax so the existing named evaluator can handle it.
  ;; ================================================================

  ;; Denormalize a stored tree body back to evaluable surface form.
  ;; - tree: the normalized tree (from tree.scm's body field)
  ;; - mapping: alist of (index . "name") from map.scm
  ;; - hash->name: procedure (hash-string -> symbol-or-#f) for
  ;;   resolving mobius-constant-ref back to names
  (define denormalize-tree
    (lambda (tree mapping hash->name)
      (define index->symbol
        (lambda (index)
          (let ((entry (assv index mapping)))
            (if entry
                (string->symbol (cdr entry))
                (string->symbol (string-append "_v" (number->string index)))))))

      (define denormalize-body
        (lambda (expression)
          (match expression
            ;; (mobius-variable N) -> symbol from mapping
            [(mobius-variable ,index) (index->symbol index)]
            ;; (mobius-primitive-ref N) -> primitive name or special form
            [(mobius-primitive-ref ,index)
             (if (< index (vector-length primitive-names))
                 (string->symbol (vector-ref primitive-names index))
                 (error 'denormalize "unknown primitive index" index))]
            ;; (mobius-primitive-constant-ref N) -> sentinel value
            [(mobius-primitive-constant-ref ,index)
             (primitive-constant-ref index)]
            ;; (mobius-constant-ref hash) -> symbol from registry
            [(mobius-constant-ref ,hash)
             (let ((name (hash->name hash)))
               (if name
                   name
                   (string->symbol
                    (string-append "«"
                                   (substring hash 0 (min 12 (string-length hash)))
                                   "»"))))]
            ;; Normalized gamma: ((mobius-primitive-ref 0) clause ...)
            [((mobius-primitive-ref 0) ,clauses ...)
             (cons 'gamma (map denormalize-clause clauses))]
            ;; Normalized lambda: ((mobius-primitive-ref 1) pattern body)
            [((mobius-primitive-ref 1) ,pattern ,body)
             (cons* 'lambda (denormalize-lambda-parameters pattern) (denormalize-body-list body))]
            ;; Normalized if: ((mobius-primitive-ref 2) test then else)
            [((mobius-primitive-ref 2) ,test ,then ,else-)
             (list 'if (denormalize-body test) (denormalize-body then) (denormalize-body else-))]
            ;; Normalized and: ((mobius-primitive-ref 3) exprs ...)
            [((mobius-primitive-ref 3) ,exprs ...)
             (cons 'and (map denormalize-body exprs))]
            ;; Normalized or: ((mobius-primitive-ref 4) exprs ...)
            [((mobius-primitive-ref 4) ,exprs ...)
             (cons 'or (map denormalize-body exprs))]
            ;; Normalized begin: ((mobius-primitive-ref 5) exprs ...)
            [((mobius-primitive-ref 5) ,exprs ...)
             (cons 'begin (map denormalize-body exprs))]
            ;; Normalized define: ((mobius-primitive-ref 6) name expr)
            [((mobius-primitive-ref 6) ,name ,value)
             (list 'define name (denormalize-body value))]
            ;; Normalized guard: ((mobius-primitive-ref 7) parts ...)
            [((mobius-primitive-ref 7) ,parts ...)
             (cons 'guard (map denormalize-body parts))]
            ;; Application: (head args ...)
            [(,elements ...) (guard (pair? elements))
             (map denormalize-body elements)]
            ;; Self-evaluating atoms
            [,other other])))

      (define denormalize-clause
        (lambda (clause)
          (match clause
            [(,pattern ,body)
             (list (denormalize-pattern pattern) (denormalize-body body))])))

      (define denormalize-pattern
        (lambda (pattern)
          (match pattern
            [(mobius-bind ,index)
             (list 'mobius-unquote (index->symbol index))]
            [(mobius-catamorphic-bind ,index)
             (list 'mobius-unquote-recurse (index->symbol index))]
            [(mobius-wildcard)
             '(mobius-unquote _)]
            [(mobius-primitive-constant-ref ,index)
             (primitive-constant-ref index)]
            [(,a . ,d) (guard (pair? pattern))
             (cons (denormalize-pattern a) (denormalize-pattern d))]
            [,_ (guard (null? pattern)) mobius-nil]
            [,other other])))

      (define denormalize-lambda-parameters
        (lambda (pattern)
          (let loop ((p pattern))
            (match p
              [() '()]
              [((mobius-bind ,index) . ,rest)
               (cons (index->symbol index) (loop rest))]
              [,_ '()]))))

      (define denormalize-body-list
        (lambda (body)
          (match body
            [((mobius-primitive-ref 5) ,exprs ...)
             (map denormalize-body exprs)]
            [,other (list (denormalize-body other))])))

      ;; Main dispatch: the top-level tree is always a gamma or lambda
      (match tree
        [((mobius-primitive-ref 0) ,clauses ...)
         (cons 'gamma (map denormalize-clause clauses))]
        [((mobius-primitive-ref 1) ,pattern ,body)
         (cons* 'lambda (denormalize-lambda-parameters pattern) (denormalize-body-list body))]
        [,other
         (error 'denormalize-tree "expected gamma or lambda at top level" other)])))

  ;; ================================================================
  ;; Tests
  ;; ================================================================

  (define test-eval
    (lambda (source)
      (let* ((expressions (mobius-read-all-string source))
             (environment (make-initial-environment)))
        (let-values (((final-environment value) (mobius-eval-top-level expressions environment)))
          value))))

  (define test-eval-environment
    (lambda (source)
      (let* ((expressions (mobius-read-all-string source))
             (environment (make-initial-environment)))
        (mobius-eval-top-level expressions environment))))

  (define ~check-evaluator-atoms
    (lambda ()
      (assert (= 42 (test-eval "42")))
      (assert (= 3.14 (test-eval "3.14")))
      (assert (equal? "hello" (test-eval "\"hello\"")))
      (assert (eq? #t (test-eval "#true")))
      (assert (eq? #f (test-eval "#false")))
      (assert (mobius-nil? (test-eval "#nil")))))

  (define ~check-evaluator-if
    (lambda ()
      (assert (= 1 (test-eval "(if #true 1 2)")))
      (assert (= 2 (test-eval "(if #false 1 2)")))
      ;; Only #false is falsy
      (assert (= 1 (test-eval "(if 0 1 2)")))
      (assert (= 1 (test-eval "(if #nil 1 2)")))
      (assert (= 1 (test-eval "(if \"\" 1 2)")))))

  (define ~check-evaluator-and-or
    (lambda ()
      (assert (= 3 (test-eval "(and 1 2 3)")))
      (assert (eq? #f (test-eval "(and 1 #false 3)")))
      (assert (= 1 (test-eval "(or 1 2 3)")))
      (assert (= 2 (test-eval "(or #false 2 3)")))
      (assert (eq? #f (test-eval "(or #false #false #false)")))))

  (define ~check-evaluator-begin
    (lambda ()
      (assert (= 3 (test-eval "(begin 1 2 3)")))))

  (define ~check-evaluator-define-nested
    (lambda ()
      (assert (= 30 (test-eval "(begin (define x 10) (define y 20) (+ x y))")))))

  (define ~check-evaluator-lambda
    (lambda ()
      (assert (= 7 (test-eval
        "(begin (define add (lambda (a b) (+ a b))) (add 3 4))")))
      ;; Lambda with single arg
      (assert (= 10 (test-eval
        "(begin (define double (lambda (x) (* x 2))) (double 5))")))))

  (define ~check-evaluator-gamma
    (lambda ()
      ;; Simple gamma with literal match on argument tree
      ;; (f 0) constructs arg tree (0 . #nil), so pattern is (0)
      (assert (= 1 (test-eval
        "(begin (define f (gamma ((0) 1) ((,x) (+ x 10)))) (f 0))")))
      (assert (= 15 (test-eval
        "(begin (define f (gamma ((0) 1) ((,x) (+ x 10)))) (f 5))")))))

  (define ~check-evaluator-gamma-catamorphic
    (lambda ()
      ;; Sum using catamorphism
      ;; (sum 1 2 3) builds arg tree (1 . (2 . (3 . #nil)))
      ;; Pattern (,head . ,(tail)) matches: head=1, tail=sum applied to (2 . (3 . #nil))
      (assert (= 6 (test-eval
        "(begin
           (define sum (gamma ((,head . ,(tail)) (+ head tail))
                              (#nil 0)))
           (sum 1 2 3))")))))

  (define ~check-evaluator-cons-car-cdr
    (lambda ()
      (assert (= 1 (test-eval "(car (cons 1 2))")))
      (assert (= 2 (test-eval "(cdr (cons 1 2))")))
      ;; Nested
      (assert (= 3 (test-eval "(car (cdr (cons 1 (cons 3 #nil))))")))))

  (define ~check-evaluator-arithmetic
    (lambda ()
      (assert (= 10 (test-eval "(+ 3 7)")))
      (assert (= 4 (test-eval "(- 10 6)")))
      (assert (= 24 (test-eval "(* 4 6)")))
      (assert (= 5 (test-eval "(/ 10 2)")))))

  (define ~check-evaluator-predicates
    (lambda ()
      (assert (eq? #t (test-eval "(integer? 42)")))
      (assert (eq? #f (test-eval "(integer? 3.14)")))
      (assert (eq? #t (test-eval "(float? 3.14)")))
      (assert (eq? #t (test-eval "(string? \"hello\")")))
      (assert (eq? #t (test-eval "(pair? (cons 1 2))")))
      (assert (eq? #f (test-eval "(pair? 42)")))
      (assert (eq? #t (test-eval "(combiner? cons)")))
      (assert (eq? #f (test-eval "(combiner? 42)")))))

  (define ~check-evaluator-comparison
    (lambda ()
      (assert (eq? #t (test-eval "(< 1 2)")))
      (assert (eq? #f (test-eval "(< 2 1)")))
      (assert (eq? #t (test-eval "(> 5 3)")))
      (assert (eq? #t (test-eval "(= 7 7)")))
      (assert (eq? #f (test-eval "(= 7 8)")))))

  (define ~check-evaluator-box
    (lambda ()
      (assert (= 42 (test-eval
        "(begin (define b (box 42)) (unbox b))")))
      (assert (= 99 (test-eval
        "(begin (define b (box 42)) (box! b 99) (unbox b))")))))

  (define ~check-evaluator-encapsulation
    (lambda ()
      (assert (eq? #t (test-eval
        "(begin
           (define my-type (encapsulation-type 12345))
           (define make-my (car my-type))
           (define my? (car (cdr my-type)))
           (define unwrap-my (car (cdr (cdr my-type))))
           (my? (make-my 42)))")))))

  (define ~check-evaluator-call-cc
    (lambda ()
      ;; Simple call/cc: capture and don't use
      (assert (= 42 (test-eval
        "(call/cc (lambda (k) 42))")))
      ;; call/cc with escape
      (assert (= 10 (test-eval
        "(+ 1 (call/cc (lambda (k) (+ 2 (continuation-apply k 9)))))")))))

  (define ~check-evaluator-display
    (lambda ()
      ;; display returns #void
      (assert (mobius-void? (test-eval "(display 42)")))))

  (define ~check-evaluator-eq
    (lambda ()
      (assert (eq? #t (test-eval "(eq? 1 1)")))
      (assert (eq? #f (test-eval "(eq? 1 2)")))
      (assert (eq? #t (test-eval "(eq? #true #true)")))
      (assert (eq? #f (test-eval "(eq? #true #false)")))))

  (define ~check-evaluator-factorial
    (lambda ()
      (let ((result (test-eval
        "(begin
           (define factorial
             (lambda (n)
               (if (= n 0) 1 (* n (factorial (- n 1))))))
           (factorial 5))")))
        (assert (= 120 result)))))

  (define ~check-evaluator-assume
    (lambda ()
      ;; Passing assertion returns #true
      (assert (eq? #t (test-eval "(assume #true)")))
      (assert (eq? #t (test-eval "(assume #true \"should pass\")")))
      (assert (eq? #t (test-eval "(assume 42)")))
      ;; Failing assertion raises a Scheme error
      (assert
       (guard (e (#t #t))
         (test-eval "(assume #false \"bad\")")
         #f))
      ;; Failing assertion without message
      (assert
       (guard (e (#t #t))
         (test-eval "(assume #false)")
         #f))))

  (define ~check-evaluator-xeno
    (lambda ()
      ;; Call Chez Scheme's string-length via xeno
      (assert (= 5 (test-eval "(xeno \"string-length\" \"hello\")")))))

  (define ~check-evaluator-string-literal
    (lambda ()
      (assert (equal? "hello world"
                       (test-eval "\"hello world\"")))))

  ;; --- Normalization tests ---

  (define no-registry (lambda (name) #f))

  (define ~check-normalize-sum
    (lambda ()
      ;; (gamma ((,head . ,(tail)) (+ head tail)) (#nil 0))
      ;; Expected: ((mobius-primitive-ref 0)
      ;;            (((mobius-bind 1) . (mobius-catamorphic-bind 2))
      ;;             ((mobius-primitive-ref 26) (mobius-variable 1) (mobius-variable 2)))
      ;;            (#nil 0))
      (let* ((source "(gamma ((,head . ,(tail)) (+ head tail)) (#nil 0))")
             (parsed (car (mobius-read-all-string source))))
        (let-values (((tree mapping) (normalize-combiner parsed 'sum no-registry)))
          ;; Check structure
          (assert (equal? '(mobius-primitive-ref 0) (car tree)))
          ;; First clause pattern
          (let ((clause1 (cadr tree)))
            (assert (equal? '(mobius-bind 1) (caar clause1)))
            (assert (equal? '(mobius-catamorphic-bind 2) (cdar clause1)))
            ;; Body: (+ head tail) => ((mobius-primitive-ref 26) (mobius-variable 1) (mobius-variable 2))
            (let ((body (cadr clause1)))
              (assert (equal? '(mobius-primitive-ref 26) (car body)))
              (assert (equal? '(mobius-variable 1) (cadr body)))
              (assert (equal? '(mobius-variable 2) (caddr body)))))
          ;; Second clause: (#nil 0)
          (let ((clause2 (caddr tree)))
            (assert (mobius-nil? (car clause2)))
            (assert (= 0 (cadr clause2))))
          ;; Mapping
          (assert (equal? "sum" (cdr (assv 0 mapping))))
          (assert (equal? "head" (cdr (assv 1 mapping))))
          (assert (equal? "tail" (cdr (assv 2 mapping))))))))

  (define ~check-normalize-factorial
    (lambda ()
      ;; (lambda (n) (if (= n 0) 1 (* n (factorial (- n 1)))))
      ;; Expected: ((mobius-primitive-ref 1)
      ;;            (mobius-bind 1)
      ;;            ((mobius-primitive-ref 2)
      ;;             ((mobius-primitive-ref 32) (mobius-variable 1) 0)
      ;;             1
      ;;             ((mobius-primitive-ref 28) (mobius-variable 1)
      ;;              ((mobius-variable 0) ((mobius-primitive-ref 27) (mobius-variable 1) 1)))))
      (let* ((source "(lambda (n) (if (= n 0) 1 (* n (factorial (- n 1)))))")
             (parsed (car (mobius-read-all-string source))))
        (let-values (((tree mapping) (normalize-combiner parsed 'factorial no-registry)))
          ;; Top level: (mobius-primitive-ref 1) for lambda
          (assert (equal? '(mobius-primitive-ref 1) (car tree)))
          ;; Pattern: (mobius-bind 1) . #nil
          (let ((pattern (cadr tree)))
            (assert (equal? '(mobius-bind 1) (car pattern))))
          ;; Body starts with if = (mobius-primitive-ref 2)
          (let ((body (caddr tree)))
            (assert (equal? '(mobius-primitive-ref 2) (car body)))
            ;; Test: (= n 0) => ((mobius-primitive-ref 32) (mobius-variable 1) 0)
            (let ((test (cadr body)))
              (assert (equal? '(mobius-primitive-ref 32) (car test)))
              (assert (equal? '(mobius-variable 1) (cadr test)))
              (assert (= 0 (caddr test)))))
          ;; Mapping: 0 -> "factorial", 1 -> "n"
          (assert (equal? "factorial" (cdr (assv 0 mapping))))
          (assert (equal? "n" (cdr (assv 1 mapping))))))))

  (define ~check-normalize-same-hash
    (lambda ()
      ;; Two combiners with different variable names but same algorithm
      ;; should produce identical normalized trees
      (let* ((source1 "(lambda (x y) (+ x y))")
             (source2 "(lambda (a b) (+ a b))")
             (parsed1 (car (mobius-read-all-string source1)))
             (parsed2 (car (mobius-read-all-string source2))))
        (let-values (((tree1 _m1) (normalize-combiner parsed1 'add1 no-registry))
                     ((tree2 _m2) (normalize-combiner parsed2 'add2 no-registry)))
          ;; Trees should be equal (names erased)
          (assert (equal? tree1 tree2))))))

  (define ~check-evaluator-mutual-recursion
    (lambda ()
      ;; Mutual recursion: my-even? and my-odd? reference each other
      (assert (eq? #t (test-eval
        "(begin
           (define my-even? (gamma ((0) #true) ((,n) (my-odd? (- n 1)))))
           (define my-odd? (gamma ((0) #false) ((,n) (my-even? (- n 1)))))
           (my-even? 4))")))
      (assert (eq? #f (test-eval
        "(begin
           (define my-even? (gamma ((0) #true) ((,n) (my-odd? (- n 1)))))
           (define my-odd? (gamma ((0) #false) ((,n) (my-even? (- n 1)))))
           (my-even? 3))")))
      (assert (eq? #t (test-eval
        "(begin
           (define my-even? (gamma ((0) #true) ((,n) (my-odd? (- n 1)))))
           (define my-odd? (gamma ((0) #false) ((,n) (my-even? (- n 1)))))
           (my-odd? 3))")))))

  ;; --- Denormalization tests ---

  (define ~check-denormalize-lambda-round-trip
    (lambda ()
      ;; Normalize then denormalize a lambda, and evaluate it
      (let* ((source "(lambda (x) (+ x x))")
             (parsed (car (mobius-read-all-string source))))
        (let-values (((tree mapping) (normalize-combiner parsed 'double no-registry)))
          (let* ((surface (denormalize-tree tree mapping (lambda (h) #f)))
                 (environment (make-initial-environment))
                 (combiner (mobius-eval surface environment))
                 (result (mobius-apply combiner
                                      (build-argument-tree (list 21))
                                      environment)))
            (assert (= 42 result)))))))

  (define ~check-denormalize-gamma-round-trip
    (lambda ()
      ;; Normalize then denormalize a gamma (catamorphic sum), evaluate
      (let* ((source "(gamma ((,head . ,(tail)) (+ head tail)) (#nil 0))")
             (parsed (car (mobius-read-all-string source))))
        (let-values (((tree mapping) (normalize-combiner parsed 'sum no-registry)))
          (let* ((surface (denormalize-tree tree mapping (lambda (h) #f)))
                 (environment (make-initial-environment))
                 (combiner (mobius-eval surface environment))
                 (arguments (cons 1 (cons 2 (cons 3 mobius-nil))))
                 (result (mobius-apply combiner arguments environment)))
            (assert (= 6 result)))))))

  )
