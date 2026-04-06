(library (bb z3)

  (export z3-available?
          z3-verify-property
          generate-smt-problem
          ~check-z3-translate
          ~check-z3-generate
          ~check-z3-parse-result)

  (import (chezscheme)
          (bb values)
          (bb evaluator)
          (bb base-library))

  ;; ================================================================
  ;; Z3 SMT solver integration for symbolic property checks.
  ;;
  ;; A check that returns a lambda triggers Z3 mode:
  ;;   (lambda (f) (lambda (x) (assume (= (f x) (* 2 x)))))
  ;; The returned lambda's params become Z3 variables, its body
  ;; becomes Z3 assertions, and the combiner-under-test is inlined
  ;; as a Z3 define-fun.
  ;; ================================================================

  ;; ================================================================
  ;; Z3 availability
  ;; ================================================================

  (define z3-available?
    (lambda ()
      (= 0 (system "command -v z3 > /dev/null 2>&1"))))

  ;; ================================================================
  ;; Type inference from combiner body
  ;; ================================================================

  ;; Primitive indices that imply numeric (Int) parameters
  ;; 31:+ 32:- 33:* 34:/ 35:< 36:> 37:=
  (define numeric-primitive-indices '(31 32 33 34 35 36 37))

  ;; Walk a body expression to infer parameter types.
  ;; env is the closure environment (to resolve symbols to primitives).
  ;; param-names is a list of symbols that are parameters.
  ;; Returns an alist ((param-name . "Int") ...).
  (define infer-param-types
    (lambda (body env param-names)
      (let ((types (make-hashtable symbol-hash symbol=?)))
        ;; Default all params to Int
        (for-each (lambda (p) (hashtable-set! types p "Int")) param-names)
        ;; Walk body looking for primitive applications
        (let walk ((expr body))
          (cond
           ((pair? expr)
            (let ((head (car expr)))
              ;; Check if head is a symbol that resolves to a numeric primitive
              (when (symbol? head)
                (let ((val (guard (exn (#t #f))
                             (name-environment-ref env head))))
                  (when (and val (mobius-primitive? val)
                             (memv (mobius-primitive-index val)
                                   numeric-primitive-indices))
                    ;; Mark all parameter symbols in arguments as Int
                    (for-each
                     (lambda (arg)
                       (when (and (symbol? arg) (memq arg param-names))
                         (hashtable-set! types arg "Int")))
                     (cdr expr)))))
              ;; Recurse into all sub-expressions
              (for-each walk expr)))
           (else (void))))
        ;; Convert hashtable to alist
        (map (lambda (p) (cons p (hashtable-ref types p "Int")))
             param-names))))

  ;; ================================================================
  ;; Expression translation: Möbius → SMT-LIB2
  ;; ================================================================

  ;; Context for translation:
  ;; - param-names: list of symbols that are Z3 variables
  ;; - combiner-name: symbol that refers to the combiner-under-test
  ;; - env: closure environment for resolving other symbols
  ;; Returns a string of SMT-LIB2 or raises an error.

  ;; Extra define-funs collected during translation (mutable, per-problem)
  (define *extra-define-funs* (make-parameter '()))
  (define *translated-combiners* (make-parameter (make-hashtable symbol-hash symbol=?)))

  (define translate-expr
    (lambda (expr param-names combiner-name env)
      (let ((z3-name (z3-fun-name combiner-name)))
        (translate-expr* expr param-names combiner-name z3-name env))))

  (define translate-expr*
    (lambda (expr param-names combiner-name z3-name env)
      (cond
       ;; Integer literal
       ((integer? expr)
        (if (< expr 0)
            (string-append "(- " (number->string (- expr)) ")")
            (number->string expr)))
       ;; Boolean
       ((eq? expr #t) "true")
       ((eq? expr #f) "false")
       ;; Symbol — parameter, combiner-under-test, or environment lookup
       ((symbol? expr)
        (cond
         ((memq expr param-names) (symbol->string expr))
         ((eq? expr combiner-name) z3-name)
         (else
          ;; Try to resolve in environment
          (let ((val (guard (exn (#t #f))
                      (name-environment-ref env expr))))
            (cond
             ((not val)
              (error 'z3-translate "unresolved symbol" expr))
             ((integer? val) (number->string val))
             ((eq? val #t) "true")
             ((eq? val #f) "false")
             ;; Primitive — shouldn't appear bare
             ((mobius-primitive? val)
              (error 'z3-translate "bare primitive reference" expr))
             (else
              (error 'z3-translate "untranslatable value" expr)))))))
       ;; Application (head arg ...)
       ((pair? expr)
        (let ((head (car expr))
              (args (cdr expr))
              (rec (lambda (e) (translate-expr* e param-names combiner-name z3-name env))))
          (cond
           ;; Special forms: if, and, or, begin, assume
           ((eq? head 'if)
            (string-append "(ite " (rec (car args)) " "
                           (rec (cadr args)) " "
                           (rec (caddr args)) ")"))
           ((eq? head 'and)
            (string-append "(and " (join-strings " " (map rec args)) ")"))
           ((eq? head 'or)
            (string-append "(or " (join-strings " " (map rec args)) ")"))
           ((eq? head 'begin)
            (rec (car (reverse args))))
           ((eq? head 'assume)
            (rec (car args)))
           ;; Symbol application
           ((symbol? head)
            (let ((val (guard (exn (#t #f))
                        (name-environment-ref env head))))
              (cond
               ;; Combiner-under-test application: (f x) → (bb_f x)
               ((eq? head combiner-name)
                (string-append "(" z3-name " "
                               (join-strings " " (map rec args))
                               ")"))
               ;; Primitive application
               ((and val (mobius-primitive? val))
                (translate-primitive-app (mobius-primitive-index val)
                                        args param-names combiner-name z3-name env))
               ;; Base library combiner (e.g., not)
               ((and val (mobius-user-combiner? val))
                (translate-known-combiner head val args param-names combiner-name z3-name env))
               (else
                (error 'z3-translate "unknown function" head)))))
           (else
            (error 'z3-translate "unsupported expression form" expr)))))
       (else
        (error 'z3-translate "untranslatable expression" expr)))))

  ;; Translate a primitive application to SMT-LIB2
  (define translate-primitive-app
    (lambda (index args param-names combiner-name z3-name env)
      (let ((translated-args (map (lambda (a)
                                    (translate-expr* a param-names combiner-name z3-name env))
                                  args)))
        (case index
          ;; 31:+ 32:- 33:* 34:/
          ((31) (string-append "(+ " (join-strings " " translated-args) ")"))
          ((32) (string-append "(- " (join-strings " " translated-args) ")"))
          ((33) (string-append "(* " (join-strings " " translated-args) ")"))
          ((34) (string-append "(div " (join-strings " " translated-args) ")"))
          ;; 35:< 36:> 37:=
          ((35) (string-append "(< " (join-strings " " translated-args) ")"))
          ((36) (string-append "(> " (join-strings " " translated-args) ")"))
          ((37) (string-append "(= " (join-strings " " translated-args) ")"))
          ;; 30: eq?
          ((30) (string-append "(= " (join-strings " " translated-args) ")"))
          ;; 22: integer? — type check, translate as true for Int vars
          ((22) "true")
          ;; 23: float? — type check
          ((23) "true")
          (else
           (error 'z3-translate
                  (string-append "unsupported primitive "
                                 (number->string index))))))))

  ;; Translate a user combiner call. For known base-library combiners (not),
  ;; emit directly. For others, generate a define-fun and emit a call.
  (define translate-known-combiner
    (lambda (name combiner args param-names combiner-name z3-name env)
      (let ((name-str (symbol->string name)))
        (cond
         ((string=? name-str "not")
          (string-append "(not "
                         (translate-expr* (car args) param-names combiner-name z3-name env)
                         ")"))
         (else
          ;; Generate a define-fun for this combiner if not already done
          (let ((safe-name (z3-fun-name name)))
            (unless (hashtable-ref (*translated-combiners*) name #f)
              (hashtable-set! (*translated-combiners*) name #t)
              (let-values (((def-str _types)
                            (generate-define-fun combiner name)))
                (*extra-define-funs*
                 (cons def-str (*extra-define-funs*)))))
            ;; Emit call
            (string-append "(" safe-name " "
                           (join-strings " "
                             (map (lambda (a)
                                    (translate-expr* a param-names combiner-name z3-name env))
                                  args))
                           ")")))))))

  ;; ================================================================
  ;; SMT-LIB2 generation
  ;; ================================================================

  ;; Generate a define-fun for the combiner-under-test.
  ;; combiner: the <mobius-combiner> to translate
  ;; fun-name: symbol to use as the function name in Z3
  ;; Returns SMT-LIB2 string.
  (define generate-define-fun
    (lambda (combiner fun-name)
      (let* ((clauses (mobius-combiner-clauses combiner))
             (clause (car clauses))
             (body (cadr clause))
             (name-alist (caddr clause))
             (env (mobius-combiner-environment combiner))
             (param-names (map car name-alist))
             (param-types (infer-param-types body env param-names))
             ;; Build parameter list for define-fun
             (param-decls
              (join-strings " "
                (map (lambda (entry)
                       (string-append "(" (symbol->string (car entry))
                                      " " (cdr entry) ")"))
                     param-types)))
             ;; Determine return type from body analysis
             (return-type (infer-return-type body env param-names))
             ;; Translate the body (fun-name not used as combiner-name here,
             ;; since the combiner's own body doesn't call itself by name
             ;; for non-recursive combiners. Use a dummy combiner-name.)
             (body-smt (translate-expr* body param-names
                                        (gensym) "" env))
             (safe-name (z3-fun-name fun-name)))
        (values
         (string-append "(define-fun " safe-name
                        " (" param-decls ") " return-type " " body-smt ")")
         param-types))))

  ;; Infer the return type of an expression.
  ;; For now: if the outermost operation is comparison/boolean → Bool,
  ;; otherwise → Int.
  (define infer-return-type
    (lambda (body env param-names)
      (cond
       ((boolean? body) "Bool")
       ((integer? body) "Int")
       ((pair? body)
        (let ((head (car body)))
          (cond
           ;; (if test then else) → infer from then branch
           ((eq? head 'if)
            (infer-return-type (caddr body) env param-names))
           ;; (begin ... last) → infer from last
           ((eq? head 'begin)
            (infer-return-type (car (reverse (cdr body))) env param-names))
           ((symbol? head)
            (let ((val (guard (exn (#t #f))
                        (name-environment-ref env head))))
              (if (and val (mobius-primitive? val))
                  (let ((index (mobius-primitive-index val)))
                    (cond
                     ((memv index '(35 36 37 30)) "Bool")  ;; < > = eq?
                     ((memv index '(31 32 33 34)) "Int")   ;; + - * /
                     (else "Int")))
                  "Int")))
           (else "Int"))))
       (else "Int"))))

  ;; Generate the full SMT-LIB2 problem.
  ;; property: the returned lambda (Z3 check)
  ;; combiner: the combiner-under-test
  ;; Returns (values smt-string combiner-fun-name) or raises error.
  (define generate-smt-problem
    (lambda (property combiner)
      (parameterize ((*extra-define-funs* '())
                     (*translated-combiners* (make-hashtable symbol-hash symbol=?)))
        (let* ((prop-clauses (mobius-combiner-clauses property))
               (prop-clause (car prop-clauses))
               (prop-body (cadr prop-clause))
               (prop-name-alist (caddr prop-clause))
               (prop-env (mobius-combiner-environment property))
               (prop-param-names (map car prop-name-alist))
               ;; Find which symbol in the property's closure is the combiner-under-test
               (combiner-name (find-combiner-name prop-env combiner))
               ;; Generate define-fun for combiner-under-test
               )
          (let-values (((define-fun-str combiner-param-types)
                        (generate-define-fun combiner combiner-name)))
            ;; Determine property variable types from combiner parameter types
            ;; by matching call sites: (f x y) maps x→param1-type, y→param2-type
            (let* ((prop-var-types
                    (infer-property-var-types prop-body prop-param-names
                                             combiner-name combiner-param-types
                                             prop-env))
                   ;; Generate variable declarations
                   (var-decls
                    (join-strings "\n"
                      (map (lambda (entry)
                             (string-append "(declare-const "
                                            (symbol->string (car entry))
                                            " " (cdr entry) ")"))
                           prop-var-types)))
                   )
              ;; Analyze body: universal vs existential
              (let-values (((mode preconditions goal)
                            (analyze-property-body prop-body)))
                (let* ((precond-strs
                        (map (lambda (a)
                               (string-append "(assert "
                                              (translate-expr a prop-param-names
                                                              combiner-name prop-env)
                                              ")"))
                             preconditions))
                       (goal-smt (translate-expr goal prop-param-names
                                                combiner-name prop-env))
                       (goal-str
                        (if (eq? mode 'universal)
                            ;; Negate for validity: unsat = holds for all
                            (string-append "(assert (not " goal-smt "))")
                            ;; Assert directly: sat = witness exists
                            (string-append "(assert " goal-smt ")")))
                       (comment
                        (if (eq? mode 'universal)
                            "; Negated property (unsat = holds for all)"
                            "; Existential property (sat = witness exists)"))
                       ;; Collect extra define-funs generated during translation
                       (extras (reverse (*extra-define-funs*)))
                       (smt (string-append
                             (if (null? extras) ""
                                 (string-append
                                  "; Helper functions\n"
                                  (join-strings "\n" extras) "\n\n"))
                             "; Combiner-under-test\n"
                             define-fun-str "\n\n"
                             "; Property variables\n"
                             var-decls "\n\n"
                             (if (null? precond-strs) ""
                                 (string-append
                                  "; Preconditions\n"
                                  (join-strings "\n" precond-strs) "\n\n"))
                             comment "\n"
                             goal-str "\n\n"
                             "(check-sat)\n"
                             "(get-model)\n")))
                  (values smt mode)))))))))

  ;; Find which symbol in the environment refers to the combiner-under-test.
  ;; Walks the environment alist looking for an eq? match.
  ;; Returns the original symbol name (used for body translation).
  (define find-combiner-name
    (lambda (env combiner)
      (let loop ((remaining env))
        (cond
         ((null? remaining)
          (error 'z3 "combiner-under-test not found in closure environment"))
         ((eq? (cdar remaining) combiner)
          (caar remaining))
         (else (loop (cdr remaining)))))))

  ;; Generate a Z3-safe function name to avoid conflicts with Z3 builtins
  (define z3-fun-name
    (lambda (sym)
      (string-append "bb_" (symbol->string sym))))

  ;; Infer property variable types from how they're used in calls to
  ;; the combiner-under-test. E.g., (f x) where f takes (a:Int) → x:Int
  (define infer-property-var-types
    (lambda (body prop-param-names combiner-name combiner-param-types env)
      (let ((types (make-hashtable symbol-hash symbol=?)))
        ;; Default all to Int
        (for-each (lambda (p) (hashtable-set! types p "Int")) prop-param-names)
        ;; Walk body looking for (combiner-name arg1 arg2 ...)
        (let walk ((expr body))
          (when (pair? expr)
            (when (and (symbol? (car expr))
                       (eq? (car expr) combiner-name))
              ;; Map each arg to combiner's param type
              (let arg-loop ((args (cdr expr))
                             (ctypes combiner-param-types))
                (when (and (pair? args) (pair? ctypes))
                  (when (and (symbol? (car args))
                             (memq (car args) prop-param-names))
                    (hashtable-set! types (car args) (cdar ctypes)))
                  (arg-loop (cdr args) (cdr ctypes)))))
            (for-each walk expr)))
        (map (lambda (p) (cons p (hashtable-ref types p "Int")))
             prop-param-names))))

  ;; Analyze a property body to determine mode and extract parts.
  ;; Returns (values mode preconditions goal)
  ;; where mode is 'universal or 'existential,
  ;; preconditions is a list of assume argument expressions,
  ;; and goal is the expression to check.
  ;;
  ;; Universal: body ends with (assume P) → negate P, unsat=pass
  ;;   (assume P) → mode=universal, preconds=(), goal=P
  ;;   (begin (assume C) ... (assume P)) → mode=universal, preconds=(C ...), goal=P
  ;;
  ;; Existential: body ends with a bare expression → assert it, sat=pass
  ;;   (> (f x) 10) → mode=existential, preconds=(), goal=(> (f x) 10)
  ;;   (begin (assume C) ... (> (f x) 10)) → mode=existential, preconds=(C ...), goal=expr
  (define analyze-property-body
    (lambda (body)
      (cond
       ;; (begin expr ...)
       ((and (pair? body) (eq? 'begin (car body)))
        (let* ((exprs (cdr body))
               (last-expr (car (reverse exprs)))
               (rest (reverse (cdr (reverse exprs))))
               ;; Collect assumes from rest as preconditions
               (preconditions
                (let loop ((remaining rest) (acc '()))
                  (if (null? remaining) (reverse acc)
                      (let ((e (car remaining)))
                        (if (and (pair? e) (eq? 'assume (car e)))
                            (loop (cdr remaining) (cons (cadr e) acc))
                            (loop (cdr remaining) acc)))))))
          (if (and (pair? last-expr) (eq? 'assume (car last-expr)))
              ;; Last is (assume P) → universal
              (values 'universal preconditions (cadr last-expr))
              ;; Last is bare expression → existential
              (values 'existential preconditions last-expr))))
       ;; Bare (assume P) → universal, no preconditions
       ((and (pair? body) (eq? 'assume (car body)))
        (values 'universal '() (cadr body)))
       ;; Bare expression → existential, no preconditions
       (else
        (values 'existential '() body)))))

  ;; ================================================================
  ;; Z3 invocation and result parsing
  ;; ================================================================

  (define invoke-z3
    (lambda (smt-string)
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports "z3 -in -T:10"
                      (buffer-mode block)
                      (make-transcoder (utf-8-codec)))))
        (display smt-string to-stdin)
        (close-output-port to-stdin)
        (let ((output (get-string-all from-stdout))
              (errors (get-string-all from-stderr)))
          (close-input-port from-stdout)
          (close-input-port from-stderr)
          (if (and (string? errors) (> (string-length errors) 0))
              (cons 'error errors)
              (parse-z3-output output))))))

  (define parse-z3-output
    (lambda (output)
      (cond
       ((string-prefix? "unsat" output)
        (cons 'pass ""))
       ((string-prefix? "sat" output)
        (let ((model (extract-model output)))
          (cons 'fail model)))
       ((string-prefix? "unknown" output)
        (cons 'error "Z3 returned unknown (timeout or undecidable)"))
       (else
        (cons 'error (string-append "unexpected Z3 output: " output))))))

  ;; Extract model assignments from Z3 output.
  ;; Z3 model format can be multi-line:
  ;;   sat
  ;;   (
  ;;     (define-fun x () Int
  ;;       1)
  ;;   )
  ;; We join everything after "sat" and parse as one string.
  (define extract-model
    (lambda (output)
      ;; Strip "sat\n" prefix, then remove outer parens and whitespace
      (let* ((body (if (string-prefix? "sat" output)
                       (substring output 3 (string-length output))
                       output))
             ;; Collapse whitespace into single spaces
             (flat (collapse-whitespace body))
             ;; Find all (define-fun name () Type value) patterns for constants
             (assignments (extract-constant-define-funs flat)))
        (if (null? assignments)
            "counterexample found"
            (string-append "counterexample: "
                           (join-strings ", " assignments))))))

  ;; Collapse runs of whitespace into single spaces
  (define collapse-whitespace
    (lambda (str)
      (let loop ((i 0) (acc '()) (in-ws #f))
        (if (>= i (string-length str))
            (list->string (reverse acc))
            (let ((ch (string-ref str i)))
              (if (char-whitespace? ch)
                  (if in-ws
                      (loop (+ i 1) acc #t)
                      (loop (+ i 1) (cons #\space acc) #t))
                  (loop (+ i 1) (cons ch acc) #f)))))))

  ;; Extract constant define-funs (ones with () param list) from flattened model
  ;; Returns list of "name = value" strings
  (define extract-constant-define-funs
    (lambda (flat)
      (let ((prefix "(define-fun ")
            (plen 12))
        (let loop ((i 0) (acc '()))
          (if (>= (+ i plen) (string-length flat))
              (reverse acc)
              (if (and (char=? (string-ref flat i) #\()
                       (>= (- (string-length flat) i) plen)
                       (string=? prefix (substring flat i (+ i plen))))
                  ;; Found a define-fun — extract name and check for ()
                  (let* ((rest-start (+ i plen))
                         ;; Find matching closing paren
                         (close (find-matching-paren flat i))
                         (segment (and close (substring flat rest-start close))))
                    (if segment
                        (let ((tokens (string-split-spaces segment)))
                          (if (and (>= (length tokens) 4)
                                   (string=? (cadr tokens) "()"))
                              ;; Constant: name () Type value...
                              ;; Value may be multi-token like (- 1)
                              (let* ((name (car tokens))
                                     (value (join-strings " " (cdddr tokens))))
                                (loop (+ (or close i) 1)
                                      (cons (string-append name " = " value)
                                            acc)))
                              (loop (+ i 1) acc)))
                        (loop (+ i 1) acc)))
                  (loop (+ i 1) acc)))))))

  ;; Find matching close paren for open paren at position start
  (define find-matching-paren
    (lambda (str start)
      (let loop ((i (+ start 1)) (depth 1))
        (cond
         ((>= i (string-length str)) #f)
         ((char=? (string-ref str i) #\() (loop (+ i 1) (+ depth 1)))
         ((char=? (string-ref str i) #\))
          (if (= depth 1) i (loop (+ i 1) (- depth 1))))
         (else (loop (+ i 1) depth))))))

  ;; ================================================================
  ;; Main entry point
  ;; ================================================================

  ;; Verify a symbolic property via Z3.
  ;; property: the returned lambda from a check
  ;; combiner: the combiner-under-test
  ;; environment: evaluation environment
  ;; Returns (status . detail) where status is pass, fail, or error.
  ;;
  ;; Two modes determined by the property body:
  ;; - Universal (body ends with assume): negate goal, unsat=pass
  ;; - Existential (body ends with bare expr): assert goal, sat=pass
  (define z3-verify-property
    (lambda (property combiner environment)
      (guard (exn
              (#t (cons 'error
                        (if (message-condition? exn)
                            (condition-message exn)
                            "Z3 translation error"))))
        (let-values (((smt mode) (generate-smt-problem property combiner)))
          (let ((z3-result (invoke-z3 smt)))
            (if (eq? mode 'universal)
                ;; Universal: unsat=pass, sat=fail
                z3-result
                ;; Existential: sat=pass (witness found), unsat=fail
                (case (car z3-result)
                  ((pass) ;; unsat — no witness exists
                   (cons 'fail "no witness found"))
                  ((fail) ;; sat — witness exists, reword "counterexample" to "witness"
                   (let ((detail (cdr z3-result)))
                     (cons 'pass
                           (if (and (string? detail)
                                    (>= (string-length detail) 16)
                                    (string=? "counterexample: "
                                              (substring detail 0 16)))
                               (string-append "witness: "
                                              (substring detail 16 (string-length detail)))
                               detail))))
                  (else z3-result))))))))

  ;; ================================================================
  ;; String helpers
  ;; ================================================================

  (define join-strings
    (lambda (sep strings)
      (if (null? strings) ""
          (let loop ((remaining (cdr strings))
                     (acc (car strings)))
            (if (null? remaining) acc
                (loop (cdr remaining)
                      (string-append acc sep (car remaining))))))))

  (define string-prefix?
    (lambda (prefix str)
      (and (>= (string-length str) (string-length prefix))
           (string=? (substring str 0 (string-length prefix)) prefix))))

  (define string-split-newlines
    (lambda (str)
      (let loop ((i 0) (start 0) (acc '()))
        (if (>= i (string-length str))
            (reverse (if (> i start)
                         (cons (substring str start i) acc)
                         acc))
            (if (char=? (string-ref str i) #\newline)
                (loop (+ i 1) (+ i 1)
                      (cons (substring str start i) acc))
                (loop (+ i 1) start acc))))))

  (define string-trim-ws
    (lambda (str)
      (let* ((len (string-length str))
             (start (let loop ((i 0))
                      (if (and (< i len) (char-whitespace? (string-ref str i)))
                          (loop (+ i 1)) i)))
             (end (let loop ((i len))
                    (if (and (> i start) (char-whitespace? (string-ref str (- i 1))))
                        (loop (- i 1)) i))))
        (if (>= start end) "" (substring str start end)))))

  (define string-split-spaces
    (lambda (str)
      (let loop ((i 0) (start 0) (acc '()))
        (if (>= i (string-length str))
            (reverse (if (> i start)
                         (cons (substring str start i) acc)
                         acc))
            (if (char=? (string-ref str i) #\space)
                (loop (+ i 1) (+ i 1)
                      (if (> i start)
                          (cons (substring str start i) acc)
                          acc))
                (loop (+ i 1) start acc))))))

  ;; ================================================================
  ;; Tests
  ;; ================================================================

  (define ~check-z3-translate
    (lambda ()
      ;; Test basic expression translation
      (assert (string=? "42" (translate-expr 42 '() 'f '())))
      (assert (string=? "true" (translate-expr #t '() 'f '())))
      (assert (string=? "x" (translate-expr 'x '(x) 'f '())))
      ;; Test negative integer
      (assert (string=? "(- 5)" (translate-expr -5 '() 'f '())))))

  (define ~check-z3-generate
    (lambda ()
      ;; Test universal SMT generation
      (let* ((env (make-initial-environment))
             (env (install-base-library env))
             (double (mobius-eval '(lambda (a) (* 2 a)) env))
             (env2 (name-environment-extend env 'f double))
             (property (mobius-eval '(lambda (x) (assume (= (f x) (* 2 x)))) env2)))
        (let-values (((smt mode) (generate-smt-problem property double)))
          (assert (string? smt))
          (assert (eq? mode 'universal))
          (assert (string-contains? smt "define-fun"))
          (assert (string-contains? smt "check-sat"))
          (assert (string-contains? smt "not"))))
      ;; Test existential SMT generation
      (let* ((env (make-initial-environment))
             (env (install-base-library env))
             (double (mobius-eval '(lambda (a) (* 2 a)) env))
             (env2 (name-environment-extend env 'f double))
             (property (mobius-eval '(lambda (x) (> (f x) 10)) env2)))
        (let-values (((smt mode) (generate-smt-problem property double)))
          (assert (string? smt))
          (assert (eq? mode 'existential))
          (assert (string-contains? smt "check-sat"))
          ;; Should NOT contain "not" wrapping the goal
          (assert (string-contains? smt "(assert (>"))))))

  (define ~check-z3-parse-result
    (lambda ()
      (assert (equal? '(pass . "") (parse-z3-output "unsat\n")))
      (assert (eq? 'fail (car (parse-z3-output "sat\n(model)\n"))))
      (assert (eq? 'error (car (parse-z3-output "unknown\n"))))))

  (define string-contains?
    (lambda (haystack needle)
      (let ((hlen (string-length haystack))
            (nlen (string-length needle)))
        (let loop ((i 0))
          (cond
           ((> (+ i nlen) hlen) #f)
           ((string=? needle (substring haystack i (+ i nlen))) #t)
           (else (loop (+ i 1))))))))

)
