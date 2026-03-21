# Closures and Higher-Order Functions

Testing closures, currying, and function composition.

## Closure captures environment

```scheme
(begin
  (define make-adder
    (lambda (n)
      (lambda (x) (+ n x))))
  (define add5 (make-adder 5))
  (display (add5 10)))
```

Expected exit code: 0
Expected output: 15

## Curried function

```scheme
(begin
  (define curry-add
    (lambda (a)
      (lambda (b)
        (+ a b))))
  (define inc (curry-add 1))
  (define add10 (curry-add 10))
  (display (inc 5))
  (display " ")
  (display (add10 3)))
```

Expected exit code: 0
Expected output: 6 13

## Function composition

```scheme
(begin
  (define compose
    (lambda (f g)
      (lambda (x) (f (g x)))))
  (define double (lambda (x) (* 2 x)))
  (define inc (lambda (x) (+ x 1)))
  (define double-then-inc (compose inc double))
  (define inc-then-double (compose double inc))
  (display (double-then-inc 5))
  (display " ")
  (display (inc-then-double 5)))
```

Expected exit code: 0
Expected output: 11 12

## Accumulator with box

```scheme
(begin
  (define make-counter
    (lambda ()
      (begin
        (define count (box 0))
        (lambda ()
          (begin
            (box! count (+ (unbox count) 1))
            (unbox count))))))
  (define c (make-counter))
  (display (c))
  (display " ")
  (display (c))
  (display " ")
  (display (c)))
```

Expected exit code: 0
Expected output: 1 2 3

## Apply-each via closure over gamma

Catamorphic recursion doesn't carry extra parameters, so we close
over the function `f` by returning a gamma from a lambda.

```scheme
(begin
  (define make-mapper
    (lambda (f)
      (gamma
        ((,head . ,(rest)) (cons (f head) rest))
        (#nil #nil))))
  (define double (lambda (x) (* 2 x)))
  (define double-each (make-mapper double))
  (define result (double-each 1 2 3))
  (display (car result))
  (display " ")
  (display (car (cdr result)))
  (display " ")
  (display (car (cdr (cdr result)))))
```

Expected exit code: 0
Expected output: 2 4 6

## Fold-right via closure over gamma

```scheme
(begin
  (define make-folder
    (lambda (f init)
      (gamma
        ((,head . ,(rest)) (f head rest))
        (#nil init))))
  (display ((make-folder + 0) 1 2 3 4 5)))
```

Expected exit code: 0
Expected output: 15
