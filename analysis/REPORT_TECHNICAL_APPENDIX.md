# Technical Appendix: Bug Details and Code Fixes

## Table of Contents
1. [Bug 1: Name Resolution at Registration Time](#bug-1-name-resolution-at-registration-time)
2. [Bug 2: DAG Enforcement](#bug-2-dag-enforcement)
3. [Bug 3: Guard Implementation](#bug-3-guard-implementation)
4. [Bug 4: Anonymous Combiner Acceptance](#bug-4-anonymous-combiner-acceptance)
5. [Bug 5: Bare Identifier in Patterns](#bug-5-bare-identifier-in-patterns)

---

## Bug 1: Name Resolution at Registration Time

### Current Behavior

When `bb add` is called, it parses and normalizes the combiner, but **does not resolve free names to content hashes**. Instead, it stores the tree with unresolved names, and the evaluator uses dynamic name-based lookup.

```scheme
;; In cli.scm, command-add:
(define command-add
  (lambda (arguments)
    ;; ... parsing ...
    (let* ((parsed (mobius-read-all-string source))
           (environment (install-base-library (make-initial-environment)))
           ;; Normalize but DON'T resolve names to hashes
           (normalized (normalize-combiner parsed name (lambda (s) #f))))  ;; <-- registry-lookup always returns #f
      ;; Store with unresolved names
      (store-combiner! root hash normalized-tree))))
```

### Problem

This means two combiners with the same logic but referencing different names will produce **different hashes**, breaking content-addressing:

```scheme
;; File A: sum.scm
(define add (lambda (x y) (+ x y)))

;; File B: sum2.scm  
(define add (lambda (a b) (+ a b)))

;; Both should produce the SAME hash (same logic)
;; But currently they produce DIFFERENT hashes because:
;; - File A normalizes to: ((mobius-primitive-ref 1) ((mobius-bind 1) . #nil) ...)
;; - File B normalizes to: ((mobius-primitive-ref 1) ((mobius-bind 1) . #nil) ...)
;; The trees ARE the same (names erased), but if they reference other combiners:

;; File C: uses-add.scm
(define double (lambda (x) (add x x)))

;; If 'add' is not resolved to its hash, the tree contains (mobius-constant-ref "add")
;; which is different from (mobius-constant-ref "ec962a9d...")
```

### Solution

Modify `command-add` to provide a proper `registry-lookup` that:
1. Checks staged combiners (not yet committed)
2. Checks committed combiners
3. Rejects if name not found

```scheme
;; In cli.scm, add helper:
(define make-registry-lookup
  (lambda (root)
    (lambda (symbol)
      ;; Check staged first
      (let ((staged-path (store-path-join root "staged" (symbol->string symbol))))
        (when (file-exists? staged-path)
          (let ((hash (call-with-input-file staged-path read)))
            (and (string? hash) hash))))
      ;; Check committed
      (let* ((combiner-dir (store-path-join root "combiners"))
             (entries (directory-list combiner-dir))
             (found (find (lambda (entry)
                            (let ((tree-path (store-path-join combiner-dir entry "tree.scm")))
                              (and (file-exists? tree-path)
                                   (let ((tree (call-with-input-file tree-path read)))
                                     ;; Check if tree references this symbol
                                     (tree-contains-symbol? tree symbol)))))
                          entries)))
        (and found (car found))))))

;; Then in normalize-combiner, use it:
(let-values (((tree mapping) (normalize-combiner parsed name (make-registry-lookup root))))
  ;; Now tree has all names resolved to hashes
  (store-combiner! root hash tree))
```

### Helper Function Needed

```scheme
(define tree-contains-symbol?
  (lambda (tree symbol)
    (cond
     ((symbol? tree) (eq? tree symbol))
     ((pair? tree)
      (or (tree-contains-symbol? (car tree) symbol)
          (tree-contains-symbol? (cdr tree) symbol)))
     (else #f))))
```

---

## Bug 2: DAG Enforcement

### Current Behavior

`store-combiner!` writes the tree without validating that all referenced combiners exist:

```scheme
(define store-combiner!)
  (lambda (root function-hash body)
    (let* ((tree-path (store-combiner-tree-path root function-hash))
           (directory (store-combiner-directory root function-hash))
           (content (scheme-write-value body)))
      (unless (file-exists? tree-path)
        (store-ensure-directory directory)
        (call-with-output-file tree-path
          (lambda (port) (display content port)))))))  ;; <-- No validation!
```

### Problem

This allows creating combiners with broken references:

```scheme
;; Register combiner A that references non-existent combiner B
(bb add a.scm)
;; a.scm contains: (define a (lambda (x) (b x)))
;; If 'b' doesn't exist, this succeeds but creates a broken reference

;; Later, trying to evaluate 'a' will fail with "unbound variable: b"
```

### Solution

Add validation before writing:

```scheme
(define validate-tree-dependencies!
  (lambda (root tree)
    (define (check-node node)
      (cond
       ((pair? node)
        (check-node (car node))
        (check-node (cdr node)))
       ((and (pair? node) (eq? 'mobius-constant-ref (car node)))
        (let ((hash (cadr node)))
          (unless (file-exists? (store-combiner-tree-path root hash))
            (error 'validate-tree-dependencies! 
                   "missing dependency: ~a" hash))))))
    (check-node tree))

(define store-combiner!)
  (lambda (root function-hash body)
    (let* ((tree-path (store-combiner-tree-path root function-hash))
           (directory (store-combiner-directory root function-hash))
           (content (scheme-write-value body)))
      (unless (file-exists? tree-path)
        ;; Validate first!
        (validate-tree-dependencies! root body)
        (store-ensure-directory directory)
        (call-with-output-file tree-path
          (lambda (port) (display content port)))))))
```

### Additional: DAG Cycle Detection

To prevent circular dependencies:

```scheme
(define detect-cycles
  (lambda (root hash visited)
    (let ((visited (cons hash visited)))
      (let ((tree (store-load-combiner root hash)))
        (define (check node)
          (cond
           ((pair? node)
            (check (car node))
            (check (cdr node)))
           ((and (pair? node) (eq? 'mobius-constant-ref (car node)))
            (let ((dep-hash (cadr node)))
              (cond
               ((memv dep-hash visited) 
                (error 'detect-cycles "circular dependency detected" dep-hash))
               ((file-exists? (store-combiner-tree-path root dep-hash))
                (detect-cycles root dep-hash visited)))))))
        (check tree))))

;; Use in store-combiner!:
(detect-cycles root function-hash '())
```

---

## Bug 3: Guard Implementation

### Current Behavior

The `guard` special form has a simplified implementation:

```scheme
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
```

### Problems

1. **Missing entry/exit gamma clauses**: Should accept patterns, not just handlers
2. **No continuation-exit binding**: Spec requires `continuation-exit` as well-known binding
3. **Simplified semantics**: Doesn't properly subsumes `dynamic-wind`

### Solution

#### Step 1: Bind continuation-exit in initial environment

```scheme
;; In evaluator.scm, make-initial-environment:
(define make-initial-environment
  (lambda ()
    ;; ... existing code ...
    (let ((environment (name-environment-extend environment 'continuation-exit
                  (make-mobius-continuation
                   (lambda (value)
                     (exit (if (integer? value) value 1)))))))
      environment)))
```

#### Step 2: Rewrite guard to accept full form

```scheme
(define eval-guard
  (lambda (parts environment)
    ;; (guard (entry clause ...) thunk (exit clause ...))
    ;; where clause = (pattern body)
    (unless (>= (length parts) 3)
      (error 'eval-guard "guard requires entry clauses, thunk, and exit clauses"))
    
    (let* ((entry-part (car parts))
           (thunk-expression (cadr parts))
           (exit-part (caddr parts))
           
           ;; Validate entry-part starts with 'entry
           (entry-clauses (if (and (pair? entry-part) (eq? 'entry (car entry-part)))
                              (cdr entry-part)
                              (error 'eval-guard "expected (entry ...) as first argument")))
           ;; Validate exit-part starts with 'exit
           (exit-clauses (if (and (pair? exit-part) (eq? 'exit (car exit-part)))
                             (cdr exit-part)
                             (error 'eval-guard "expected (exit ...) as third argument"))))
      
      (call/cc
       (lambda (outer-exit)
         (let ((entry-continuation
                (make-mobius-continuation
                 (lambda (value)
                   ;; Match against entry clauses
                   (match-entry-clauses entry-clauses value environment outer-exit)))))
           
           (let ((result
                  (call/cc
                   (lambda (inner-exit)
                     ;; Install entry continuation
                     (let ((guard-env (name-environment-extend environment 'continuation-entry entry-continuation)))
                       (mobius-eval thunk-expression guard-env))))))
             
             ;; If we got here normally, match against exit clauses
             (match-exit-clauses exit-clauses result environment outer-exit))))))))

(define match-entry-clauses
  (lambda (clauses value environment outer-exit)
    (let loop ((remaining clauses))
      (if (null? remaining)
          ;; No match, deliver to outer exit
          ((mobius-continuation-procedure outer-exit) value)
          (let* ((clause (car remaining))
                 (pattern (car clause))
                 (body (cadr clause))
                 (bindings (pattern-match pattern value #f
                                           (lambda (c v) (mobius-apply c v environment))
                                           (lambda (e env) (mobius-eval e env))
                                           environment)))
            (if bindings
                (let ((extended-env (extend-environment-with-bindings environment bindings)))
                  (mobius-eval body extended-env))
                (loop (cdr remaining))))))))

(define match-exit-clauses
  (lambda (clauses value environment outer-exit)
    (let loop ((remaining clauses))
      (if (null? remaining)
          ;; No match, deliver to outer exit
          ((mobius-continuation-procedure outer-exit) value)
          (let* ((clause (car remaining))
                 (pattern (car clause))
                 (body (cadr clause))
                 (bindings (pattern-match pattern value #f
                                           (lambda (c v) (mobius-apply c v environment))
                                           (lambda (e env) (mobius-eval e env))
                                           environment)))
            (if bindings
                (let ((extended-env (extend-environment-with-bindings environment bindings)))
                  (mobius-eval body extended-env))
                (loop (cdr remaining))))))))
```

#### Step 3: Add continuation-extend to base library

```scheme
;; In base-library.scm:
(define continuation-extend
  (lambda (continuation combiner)
    (call/cc
     (lambda (k)
       (let ((extended-cont (make-mobius-continuation
                              (lambda (value)
                                (call/cc
                                 (lambda (k2)
                                   ((mobius-continuation-procedure continuation) value)))))))
         ((mobius-continuation-procedure continuation) 
          (mobius-apply combiner 
                       (build-argument-tree (list extended-cont))
                       (make-initial-environment))))))))
```

---

## Bug 4: Anonymous Combiner Acceptance

### Current Behavior

The `normalize-combiner` function accepts any gamma or lambda expression, even if it's not bound to a name:

```scheme
(define normalize-combiner
  (lambda (expression self-name registry-lookup)
    ;; ...
    (if (and (pair? expression) (eq? 'gamma (car expression)))
        (normalize-gamma)
        (if (and (pair? expression) (eq? 'lambda (car expression)))
            (normalize-lambda)
            (error 'normalize-combiner "expected gamma or lambda" expression))))))
```

### Problem

This allows:
```scheme
;; Anonymous gamma as argument
(define apply-f (lambda (f x) (f x)))
(apply-f (gamma ((,x) x)) 42)  ;; Anonymous gamma - should be rejected!
```

Spec (§3.2) states: "Every `gamma` or `lambda` must be bound to a name via `define`. No anonymous combiners as arguments."

### Solution

Add validation in `normalize-combiner`:

```scheme
(define normalize-combiner
  (lambda (expression self-name registry-lookup)
    ;; Check that expression is a define
    (unless (and (pair? expression) (eq? 'define (car expression)))
      (error 'normalize-combiner "anonymous combiner not allowed; use define" expression))
    
    (let ((defined-expression (caddr expression)))  ;; Skip 'define and name
      (if (and (pair? defined-expression) (eq? 'gamma (car defined-expression)))
          (normalize-gamma defined-expression)
          (if (and (pair? defined-expression) (eq? 'lambda (car defined-expression)))
              (normalize-lambda defined-expression)
              (error 'normalize-combiner "expected gamma or lambda after define" expression)))))))
```

### Additional: Check at registration time

```scheme
;; In cli.scm, command-add:
(define command-add
  (lambda (arguments)
    ;; ...
    (let* ((parsed (mobius-read-all-string source)))
      ;; Check that top-level is a define
      (unless (and (pair? parsed) (eq? 'define (caar parsed)))
        (display "bb add: top-level must be a define\n" (current-error-port))
        (exit 1))
      ;; ... rest of processing ...
      )))
```

---

## Bug 5: Bare Identifier in Patterns

### Current Behavior

The reader converts `,x` to `(mobius-unquote x)`, but a bare identifier `x` in pattern position is treated as a literal symbol match:

```scheme
;; Pattern: x  (bare identifier)
;; This is treated as a literal symbol match, not rejected

gamma ((x) 1)  ;; Matches only the symbol 'x', not a bind
```

### Problem

Spec (§5.2) states: "Bare identifiers in patterns are forbidden. The registrar rejects them."

This means patterns like:
```scheme
(gamma ((x) 1) ...)  ;; Should be REJECTED
```

Should be rejected, but currently are accepted (and match literally).

### Solution

Add validation in `process-pattern`:

```scheme
(define process-pattern
  (lambda (pattern next-index)
    (cond
     ;; Bare symbol in pattern position - REJECT
     ((symbol? pattern)
      (error 'process-pattern "bare identifier in pattern; use ,x for bind, ,_ for wildcard" pattern))
     
     ;; (mobius-unquote x) => (mobius-bind N)
     ((and (pair? pattern)
           (eq? 'mobius-unquote (car pattern)))
      ;; ... existing code ...
      )
     
     ;; ... rest of existing code ...
     )))
```

### Additional: Validate at gamma processing time

```scheme
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
            ;; Validate pattern doesn't contain bare symbols
            (validate-pattern-no-bare-symbols pattern)
            (let-values (((internal next names)
                          (process-pattern pattern next-index)))
              (loop (cdr remaining)
                    next
                    (cons (list internal body names) processed))))))))

(define validate-pattern-no-bare-symbols
  (lambda (pattern)
    (cond
     ((symbol? pattern)
      (error 'validate-pattern "bare identifier in pattern" pattern))
     ((pair? pattern)
      (validate-pattern-no-bare-symbols (car pattern))
      (validate-pattern-no-bare-symbols (cdr pattern)))
     (else #t))))
```

---

## Summary of Changes

| Bug | File | Lines to Change | Complexity |
|-----|------|-----------------|------------|
| 1 | cli.scm, evaluator.scm | ~50 lines | Medium |
| 2 | store.scm | ~30 lines | Medium |
| 3 | evaluator.scm, base-library.scm | ~80 lines | High |
| 4 | evaluator.scm, cli.scm | ~20 lines | Low |
| 5 | evaluator.scm | ~15 lines | Low |

**Total**: ~195 lines of code changes to fix all critical bugs

---

## Testing the Fixes

After implementing these fixes, add tests:

```scheme
;; Test name resolution
(define ~check-registration-name-resolution
  (lambda ()
    ;; Add combiner A
    (command-add '("a.scm") "en")
    ;; Add combiner B that references A
    (command-add '("b.scm") "en")  ;; b.scm: (define b (lambda (x) (a x)))
    ;; Verify B's tree contains A's hash, not symbol 'a'
    ))

;; Test DAG enforcement
(define ~check-dag-enforcement
  (lambda ()
    (assert (guard (e [(exn? e) #t])
              (command-add '("broken.scm") "en")  ;; references non-existent combiner
              #f))
    ))

;; Test guard full form
(define ~check-guard-full-form
  (lambda ()
    (assert (equal? 42
              (test-eval
               "(guard (entry ((,x) x)) 42 (exit ((,y) y)))")))
    ))

;; Test anonymous combiner rejection
(define ~check-anonymous-combiner-rejection
  (lambda ()
    (assert (guard (e [(exn? e) #t])
              (normalize-combiner '(gamma ((,x) x)) 'test (lambda (s) #f))
              #f))
    ))

;; Test bare identifier rejection
(define ~check-bare-identifier-rejection
  (lambda ()
    (assert (guard (e [(exn? e) #t])
              (process-pattern 'x 1)
              #f))
    ))
```
