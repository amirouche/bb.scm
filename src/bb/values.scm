(library (bb values)

  (export ;; Mobius value constructors and predicates
          mobius-nil
          mobius-nil?
          mobius-void
          mobius-void?
          mobius-true
          mobius-false
          mobius-eof
          mobius-eof?
          mobius-true?
          mobius-false?
          mobius-boolean?
          mobius-integer?
          mobius-float?
          mobius-char?
          mobius-string?
          mobius-pair?
          mobius-box?
          mobius-combiner?
          mobius-user-combiner?
          mobius-continuation?
          ;; Box operations
          make-mobius-box
          mobius-box-ref
          mobius-box-set!
          ;; Capsule operations
          make-mobius-capsule
          mobius-capsule?
          mobius-capsule-type-id
          mobius-capsule-value
          ;; Combiner operations
          make-mobius-combiner
          mobius-combiner-clauses
          mobius-combiner-environment
          mobius-combiner-name
          ;; Primitive combiner
          make-mobius-primitive
          mobius-primitive?
          mobius-primitive-index
          mobius-primitive-name
          ;; Continuation
          make-mobius-continuation
          mobius-continuation-procedure
          ;; Conversion
          mobius-truthy?
          mobius-list->scheme-list
          scheme-list->mobius-list
          ;; Primitive constant registry
          primitive-constant-registry
          primitive-constant-ref
          primitive-constant-index
          ;; Tests
          ~check-values-nil
          ~check-values-box
          ~check-values-capsule
          ~check-values-combiner
          ~check-values-list-conversion
          ~check-values-truthy
          ~check-values-primitive-constants)

  (import (chezscheme))

  ;; --- Singletons ---

  ;; #nil maps to Scheme '().  Truthy in Mobius (only #false is falsy).
  (define mobius-nil '())
  (define mobius-nil? null?)

  ;; #void maps to Scheme (void).
  (define mobius-void (void))
  (define mobius-void?
    (lambda (value)
      (eq? value (void))))

  ;; #eof maps to Scheme (eof-object).
  (define mobius-eof (eof-object))
  (define mobius-eof? eof-object?)

  ;; #true and #false map to Scheme #t and #f
  (define mobius-true #t)
  (define mobius-false #f)

  (define mobius-true?
    (lambda (value)
      (eq? value #t)))

  (define mobius-false?
    (lambda (value)
      (eq? value #f)))

  ;; --- Primitive constant registry ---
  ;; Maps integer indices to singleton values.
  ;; 0 = #nil, 1 = #true, 2 = #false, 3 = #void, 4 = #eof

  (define primitive-constant-registry
    (vector mobius-nil mobius-true mobius-false mobius-void mobius-eof))

  (define primitive-constant-ref
    (lambda (index)
      (vector-ref primitive-constant-registry index)))

  (define primitive-constant-index
    (lambda (value)
      (cond
       ((mobius-nil? value) 0)
       ((eq? value #t) 1)
       ((eq? value #f) 2)
       ((mobius-void? value) 3)
       ((mobius-eof? value) 4)
       (else #f))))

  ;; --- Type predicates ---

  (define mobius-boolean?
    (lambda (value)
      (boolean? value)))

  (define mobius-integer?
    (lambda (value)
      (and (integer? value) (exact? value))))

  (define mobius-float?
    (lambda (value)
      (flonum? value)))

  (define mobius-char?
    (lambda (value)
      (char? value)))

  (define mobius-string?
    (lambda (value)
      (string? value)))

  (define mobius-pair?
    (lambda (value)
      (pair? value)))

  ;; --- Boxes ---

  (define-record-type <mobius-box>
    (nongenerative mobius-box-9a3f7c2e)
    (fields (mutable content mobius-box-ref mobius-box-set!))
    (protocol (lambda (new) (lambda (value) (new value)))))

  (define make-mobius-box
    (lambda (value)
      (make-<mobius-box> value)))

  (define mobius-box?
    (lambda (value)
      (<mobius-box>? value)))

  ;; --- Capsules ---

  (define-record-type <mobius-capsule>
    (nongenerative mobius-capsule-4b8e1d6f)
    (fields type-id value)
    (protocol (lambda (new) (lambda (type-id value) (new type-id value)))))

  (define make-mobius-capsule
    (lambda (type-id value)
      (make-<mobius-capsule> type-id value)))

  (define mobius-capsule?
    (lambda (value)
      (<mobius-capsule>? value)))

  (define mobius-capsule-type-id
    (lambda (capsule)
      (<mobius-capsule>-type-id capsule)))

  (define mobius-capsule-value
    (lambda (capsule)
      (<mobius-capsule>-value capsule)))

  ;; --- Combiners (user-defined gamma/lambda closures) ---

  (define-record-type <mobius-combiner>
    (nongenerative mobius-combiner-7c4a2e9b)
    (fields clauses environment name)
    (protocol (lambda (new)
                (lambda (clauses env name)
                  (new clauses env name)))))

  (define make-mobius-combiner
    (lambda (clauses env name)
      (make-<mobius-combiner> clauses env name)))

  (define mobius-user-combiner?
    (lambda (value)
      (<mobius-combiner>? value)))

  (define mobius-combiner?
    (lambda (value)
      (or (<mobius-combiner>? value)
          (mobius-primitive? value))))

  (define mobius-combiner-clauses
    (lambda (combiner)
      (<mobius-combiner>-clauses combiner)))

  (define mobius-combiner-environment
    (lambda (combiner)
      (<mobius-combiner>-environment combiner)))

  (define mobius-combiner-name
    (lambda (combiner)
      (<mobius-combiner>-name combiner)))

  ;; --- Primitive combiners ---

  (define-record-type <mobius-primitive>
    (nongenerative mobius-primitive-1e5f8a3d)
    (fields index name)
    (protocol (lambda (new) (lambda (index name) (new index name)))))

  (define make-mobius-primitive
    (lambda (index name)
      (make-<mobius-primitive> index name)))

  (define mobius-primitive?
    (lambda (value)
      (<mobius-primitive>? value)))

  (define mobius-primitive-index
    (lambda (primitive)
      (<mobius-primitive>-index primitive)))

  (define mobius-primitive-name
    (lambda (primitive)
      (<mobius-primitive>-name primitive)))

  ;; --- Continuations ---

  (define-record-type <mobius-continuation>
    (nongenerative mobius-continuation-3d9c7b1e)
    (fields procedure)
    (protocol (lambda (new) (lambda (procedure) (new procedure)))))

  (define make-mobius-continuation
    (lambda (procedure)
      (make-<mobius-continuation> procedure)))

  (define mobius-continuation?
    (lambda (value)
      (<mobius-continuation>? value)))

  (define mobius-continuation-procedure
    (lambda (continuation)
      (<mobius-continuation>-procedure continuation)))

  ;; --- Truthiness ---

  ;; In Mobius, only #false is falsy.
  (define mobius-truthy?
    (lambda (value)
      (not (eq? value #f))))

  ;; --- List conversion ---

  ;; Convert a Mobius list (pairs ending in mobius-nil) to a Scheme list.
  (define mobius-list->scheme-list
    (lambda (value)
      (let loop ((current value)
                 (accumulator '()))
        (cond
         ((mobius-nil? current)
          (reverse accumulator))
         ((pair? current)
          (loop (cdr current) (cons (car current) accumulator)))
         (else
          ;; Improper list — return what we have plus the tail
          (append (reverse accumulator) current))))))

  ;; Convert a Scheme list to a Mobius list (pairs ending in mobius-nil).
  (define scheme-list->mobius-list
    (lambda (list)
      (let loop ((remaining list))
        (if (null? remaining)
            mobius-nil
            (cons (car remaining) (loop (cdr remaining)))))))

  ;; --- Tests ---

  (define ~check-values-nil
    (lambda ()
      (assert (mobius-nil? mobius-nil))
      (assert (mobius-nil? '()))
      (assert (not (mobius-nil? 0)))
      (assert (mobius-void? mobius-void))
      (assert (mobius-void? (void)))
      (assert (mobius-eof? mobius-eof))
      (assert (mobius-eof? (eof-object)))))

  (define ~check-values-box
    (lambda ()
      (let ((b (make-mobius-box 42)))
        (assert (mobius-box? b))
        (assert (= 42 (mobius-box-ref b)))
        (mobius-box-set! b 99)
        (assert (= 99 (mobius-box-ref b)))
        ;; Box identity: different boxes are not eq?
        (assert (not (eq? b (make-mobius-box 99)))))))

  (define ~check-values-capsule
    (lambda ()
      (let* ((type-id 12345)
             (capsule (make-mobius-capsule type-id "hello")))
        (assert (mobius-capsule? capsule))
        (assert (= type-id (mobius-capsule-type-id capsule)))
        (assert (equal? "hello" (mobius-capsule-value capsule)))
        (assert (not (mobius-capsule? 42))))))

  (define ~check-values-combiner
    (lambda ()
      (let ((primitive (make-mobius-primitive 8 "cons")))
        (assert (mobius-primitive? primitive))
        (assert (mobius-combiner? primitive))
        (assert (= 8 (mobius-primitive-index primitive)))
        (assert (equal? "cons" (mobius-primitive-name primitive))))))

  (define ~check-values-list-conversion
    (lambda ()
      (let* ((scheme-list '(1 2 3))
             (mobius-list (scheme-list->mobius-list scheme-list))
             (back (mobius-list->scheme-list mobius-list)))
        (assert (pair? mobius-list))
        (assert (= 1 (car mobius-list)))
        (assert (mobius-nil? (cdr (cdr (cdr mobius-list)))))
        (assert (equal? scheme-list back)))))

  (define ~check-values-truthy
    (lambda ()
      ;; Only #false is falsy
      (assert (not (mobius-truthy? #f)))
      ;; Everything else is truthy
      (assert (mobius-truthy? #t))
      (assert (mobius-truthy? 0))
      (assert (mobius-truthy? ""))
      (assert (mobius-truthy? mobius-nil))
      (assert (mobius-truthy? mobius-void))))

  (define ~check-values-primitive-constants
    (lambda ()
      (assert (= 0 (primitive-constant-index mobius-nil)))
      (assert (= 1 (primitive-constant-index #t)))
      (assert (= 2 (primitive-constant-index #f)))
      (assert (= 3 (primitive-constant-index mobius-void)))
      (assert (= 4 (primitive-constant-index mobius-eof)))
      (assert (mobius-nil? (primitive-constant-ref 0)))
      (assert (eq? #t (primitive-constant-ref 1)))
      (assert (eq? #f (primitive-constant-ref 2)))
      (assert (mobius-void? (primitive-constant-ref 3)))
      (assert (mobius-eof? (primitive-constant-ref 4)))
      (assert (not (primitive-constant-index 42)))))

  )
