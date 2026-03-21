# Advanced Features

Boxes (mutation), capsules (encapsulation), and call/cc.

## Box mutation

```scheme
(begin
  (define b (box 0))
  (box! b 42)
  (display (unbox b)))
```

Expected exit code: 0
Expected output: 42

## Capsules (encapsulation types)

`encapsulation-type` returns a triple: constructor, predicate, accessor.
Only the accessor from the same type can open the capsule.

```scheme
(begin
  (define triple (encapsulation-type 1))
  (define make-point (car triple))
  (define point? (car (cdr triple)))
  (define point-value (car (cdr (cdr triple))))
  (define p (make-point 42))
  (display (point? p))
  (display " ")
  (display (point-value p)))
```

Expected exit code: 0
Expected output: #true 42

## Call/cc for early exit

`call/cc` captures the current continuation. Invoking it aborts the
rest of the body. The continuation returns the value directly.

```scheme
(begin
  (define result
    (call/cc (lambda (k)
      (display "before ")
      (k 42)
      (display "after "))))
  (display result))
```

Expected exit code: 0
Expected output: before 42

## Lambda (operative form)

Lambda captures the argument tree directly without building
an argument tree from evaluated arguments.

```scheme
(begin
  (define add (lambda (a b) (+ a b)))
  (display (add 3 4)))
```

Expected exit code: 0
Expected output: 7

## Higher-order: map-like via gamma

```scheme
(begin
  (define double-each
    (gamma
      ((,head . ,(rest)) (cons (* 2 head) rest))
      (#nil #nil)))
  (define result (double-each 1 2 3))
  (display (car result))
  (display " ")
  (display (car (cdr result)))
  (display " ")
  (display (car (cdr (cdr result)))))
```

Expected exit code: 0
Expected output: 2 4 6
