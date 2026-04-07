(library (bb base-library)

  (export install-base-library
          ~check-base-library-list
          ~check-base-library-not
          ~check-base-library-equal)

  (import (chezscheme)
          (bb values)
          (bb reader)
          (bb evaluator))

  ;; The Mobius base library: combiners written in Mobius itself.
  ;; These are evaluated at startup and installed into the environment.

  (define base-library-source
    '(
      ;; list — identity combiner. Returns the argument tree unchanged.
      "(define list (gamma (,args args)))"

      ;; not — boolean negation
      "(define not (gamma ((#false) #true) ((,_) #false)))"

      ;; equal? — recursive structural comparison
      "(define equal?
         (lambda (a b)
           (if (and (pair? a) (pair? b))
               (and (equal? (car a) (car b))
                    (equal? (cdr a) (cdr b)))
               (if (and (box? a) (box? b))
                   (equal? (unbox a) (unbox b))
                   (eq? a b)))))"

      ;; capsule-constructor — extract constructor from encapsulation-type result
      "(define capsule-constructor (gamma ((,type) (car type))))"

      ;; capsule-predicate — extract predicate
      "(define capsule-predicate (gamma ((,type) (car (cdr type)))))"

      ;; capsule-unwrap — extract accessor
      "(define capsule-unwrap (gamma ((,type) (car (cdr (cdr type))))))"

      ;; length — count elements in a list
      "(define length
         (lambda (lst)
           (if (pair? lst)
               (+ 1 (length (cdr lst)))
               0)))"

      ;; string-length — length of a string via string->list
      "(define string-length (lambda (s) (length (string->list s))))"

      ;; bit-length — number of bits via number->list
      "(define bit-length (lambda (n) (length (number->list n))))"

      ;; butlast — all elements except the last
      "(define butlast
         (lambda (lst)
           (if (pair? (cdr lst))
               (cons (car lst) (butlast (cdr lst)))
               #nil)))"

      ;; arithmetic-shift-right — drop last k bits
      "(define arithmetic-shift-right
         (lambda (n k)
           (if (= k 0) n
               (arithmetic-shift-right (list->number (butlast (number->list n))) (- k 1)))))"

      ;; arithmetic-shift-left — multiply by 2, k times
      "(define arithmetic-shift-left
         (lambda (n k)
           (if (= k 0) n
               (arithmetic-shift-left (* n 2) (- k 1)))))"

      ;; error — display message and exit
      "(define error
         (lambda (code message data)
           (begin
             (display message)
             (display \": \")
             (display data)
             (display \"\\n\")
             (continuation-apply continuation-exit code))))"
      ))

  ;; Install base library into an environment
  (define install-base-library
    (lambda (environment)
      (let loop ((sources base-library-source)
                 (environment environment))
        (if (null? sources)
            environment
            (let* ((source (car sources))
                   (expressions (mobius-read-all-string source)))
              (let-values (((new-environment value)
                            (mobius-eval-top-level expressions environment)))
                (loop (cdr sources) new-environment)))))))

  ;; --- Tests ---

  (define make-test-environment
    (lambda ()
      (install-base-library (make-initial-environment))))

  (define test-with-base
    (lambda (source)
      (let* ((expressions (mobius-read-all-string source))
             (environment (make-test-environment)))
        (let-values (((final-environment value) (mobius-eval-top-level expressions environment)))
          value))))

  (define ~check-base-library-list
    (lambda ()
      ;; (list 1 2 3) => (1 . (2 . (3 . #nil)))
      (let ((result (test-with-base "(list 1 2 3)")))
        (assert (pair? result))
        (assert (= 1 (car result)))
        (assert (= 2 (car (cdr result))))
        (assert (= 3 (car (cdr (cdr result)))))
        (assert (mobius-nil? (cdr (cdr (cdr result))))))))

  (define ~check-base-library-not
    (lambda ()
      (assert (eq? #t (test-with-base "(not #false)")))
      (assert (eq? #f (test-with-base "(not #true)")))
      (assert (eq? #f (test-with-base "(not 42)")))))

  (define ~check-base-library-equal
    (lambda ()
      (assert (eq? #t (test-with-base "(equal? 1 1)")))
      (assert (eq? #f (test-with-base "(equal? 1 2)")))
      ;; Deep equality on lists
      (assert (eq? #t (test-with-base
        "(equal? (list 1 2 3) (list 1 2 3))")))
      (assert (eq? #f (test-with-base
        "(equal? (list 1 2 3) (list 1 2 4))")))))

  )
