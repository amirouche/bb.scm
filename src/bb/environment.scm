(library (bb environment)

  (export environment-empty
          environment-extend
          environment-extend*
          environment-ref
          environment-set!
          environment-has?
          environment-size
          ~check-environment-empty
          ~check-environment-extend-and-ref
          ~check-environment-extend-multiple
          ~check-environment-set-mutable)

  (import (chezscheme))

  ;; An environment is a vector-based frame list for de Bruijn indexed
  ;; lookups. Each frame is a vector of values. Index 0 in the
  ;; innermost frame is the most recently bound variable.
  ;;
  ;; For the Mobius evaluator, index 0 is always self (the enclosing
  ;; combiner). Pattern variables start at index 1.
  ;;
  ;; We use a simple list of vectors. environment-ref walks frames,
  ;; subtracting each frame's length until the index falls within
  ;; range.

  ;; A flat vector-based environment. We store bindings in a single
  ;; mutable vector that grows as needed via environment-extend.

  (define environment-empty
    (lambda ()
      '()))

  (define environment-extend
    (lambda (environment value)
      (cons (vector value) environment)))

  (define environment-extend*
    (lambda (environment values)
      (if (null? values)
          environment
          (cons (list->vector values) environment))))

  (define environment-ref
    (lambda (environment index)
      (let loop ((frames environment)
                 (remaining index))
        (when (null? frames)
          (error 'environment-ref "index out of range" index))
        (let* ((frame (car frames))
               (frame-length (vector-length frame)))
          (if (< remaining frame-length)
              (vector-ref frame remaining)
              (loop (cdr frames)
                    (- remaining frame-length)))))))

  (define environment-set!
    (lambda (environment index value)
      (let loop ((frames environment)
                 (remaining index))
        (when (null? frames)
          (error 'environment-set! "index out of range" index))
        (let* ((frame (car frames))
               (frame-length (vector-length frame)))
          (if (< remaining frame-length)
              (vector-set! frame remaining value)
              (loop (cdr frames)
                    (- remaining frame-length)))))))

  (define environment-has?
    (lambda (environment index)
      (let loop ((frames environment)
                 (remaining index))
        (if (null? frames)
            #f
            (let* ((frame (car frames))
                   (frame-length (vector-length frame)))
              (if (< remaining frame-length)
                  #t
                  (loop (cdr frames)
                        (- remaining frame-length))))))))

  (define environment-size
    (lambda (environment)
      (let loop ((frames environment)
                 (total 0))
        (if (null? frames)
            total
            (loop (cdr frames)
                  (+ total (vector-length (car frames))))))))

  ;; Tests

  (define ~check-environment-empty
    (lambda ()
      (let ((environment (environment-empty)))
        (assert (= 0 (environment-size environment)))
        (assert (not (environment-has? environment 0))))))

  (define ~check-environment-extend-and-ref
    (lambda ()
      (let* ((environment (environment-empty))
             (environment (environment-extend environment 'self))
             (environment (environment-extend* environment '(10 20 30))))
        (assert (= 4 (environment-size environment)))
        ;; Most recent frame first: (10 20 30), then (self)
        (assert (equal? 10 (environment-ref environment 0)))
        (assert (equal? 20 (environment-ref environment 1)))
        (assert (equal? 30 (environment-ref environment 2)))
        (assert (equal? 'self (environment-ref environment 3))))))

  (define ~check-environment-extend-multiple
    (lambda ()
      (let* ((environment (environment-empty))
             (environment (environment-extend environment 'a))
             (environment (environment-extend environment 'b))
             (environment (environment-extend environment 'c)))
        (assert (equal? 'c (environment-ref environment 0)))
        (assert (equal? 'b (environment-ref environment 1)))
        (assert (equal? 'a (environment-ref environment 2))))))

  (define ~check-environment-set-mutable
    (lambda ()
      (let* ((environment (environment-empty))
             (environment (environment-extend* environment '(1 2 3))))
        (environment-set! environment 1 42)
        (assert (equal? 42 (environment-ref environment 1)))
        (assert (equal? 1 (environment-ref environment 0)))
        (assert (equal? 3 (environment-ref environment 2))))))

  )
