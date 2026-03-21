# Catamorphic Arithmetic Evaluator

A tree-walking arithmetic expression evaluator built entirely with
gamma's catamorphic `,(a)` syntax. Each `,(a)` in a pattern
automatically applies the enclosing gamma to the matched
sub-expression — no explicit recursion needed.

Expression trees are Möbius lists tagged with a string:

- `("num" n)` — numeric literal
- `("add" e1 e2)` — addition
- `("sub" e1 e2)` — subtraction
- `("mul" e1 e2)` — multiplication
- `("neg" e)` — negation
- `("do" e)` — identity entry node

The `"do"` node is necessary because calling `(arith-eval tree)`
wraps tree in `(cons tree #nil)`, but catamorphic bind passes the
matched value directly as the argument tree. The `"do"` node
bridges the two conventions.

## Literal

```scheme
(begin
  (define make-num (lambda (n) (cons "num" (cons n #nil))))
  (define arith-eval
    (gamma
      (("num" ,n) n)
      (("do" ,(result)) result)))
  (display (arith-eval "do" (make-num 42))))
```

Expected exit code: 0
Expected output: 42

## Addition

```scheme
(begin
  (define make-num (lambda (n) (cons "num" (cons n #nil))))
  (define make-add (lambda (a b) (cons "add" (cons a (cons b #nil)))))
  (define arith-eval
    (gamma
      (("num" ,n) n)
      (("add" ,(a) ,(b)) (+ a b))
      (("do" ,(result)) result)))
  (display (arith-eval "do" (make-add (make-num 3) (make-num 4)))))
```

Expected exit code: 0
Expected output: 7

## Nested multiplication and addition

```scheme
(begin
  (define make-num (lambda (n) (cons "num" (cons n #nil))))
  (define make-add (lambda (a b) (cons "add" (cons a (cons b #nil)))))
  (define make-mul (lambda (a b) (cons "mul" (cons a (cons b #nil)))))
  (define arith-eval
    (gamma
      (("num" ,n) n)
      (("add" ,(a) ,(b)) (+ a b))
      (("mul" ,(a) ,(b)) (* a b))
      (("do" ,(result)) result)))
  (display (arith-eval "do" (make-mul (make-num 5) (make-add (make-num 2) (make-num 3))))))
```

Expected exit code: 0
Expected output: 25

## Full evaluator with subtraction and negation

```scheme
(begin
  (define make-num (lambda (n) (cons "num" (cons n #nil))))
  (define make-add (lambda (a b) (cons "add" (cons a (cons b #nil)))))
  (define make-sub (lambda (a b) (cons "sub" (cons a (cons b #nil)))))
  (define make-mul (lambda (a b) (cons "mul" (cons a (cons b #nil)))))
  (define make-neg (lambda (a) (cons "neg" (cons a #nil))))
  (define arith-eval
    (gamma
      (("num" ,n) n)
      (("add" ,(a) ,(b)) (+ a b))
      (("sub" ,(a) ,(b)) (- a b))
      (("mul" ,(a) ,(b)) (* a b))
      (("neg" ,(a)) (- 0 a))
      (("do" ,(result)) result)))
  (display (arith-eval "do" (make-sub (make-mul (make-num 10) (make-num 3)) (make-add (make-num 5) (make-num 7))))))
```

Expected exit code: 0
Expected output: 18

## Negation of compound expression

```scheme
(begin
  (define make-num (lambda (n) (cons "num" (cons n #nil))))
  (define make-add (lambda (a b) (cons "add" (cons a (cons b #nil)))))
  (define make-neg (lambda (a) (cons "neg" (cons a #nil))))
  (define arith-eval
    (gamma
      (("num" ,n) n)
      (("add" ,(a) ,(b)) (+ a b))
      (("neg" ,(a)) (- 0 a))
      (("do" ,(result)) result)))
  (display (arith-eval "do" (make-neg (make-add (make-num 3) (make-num 4))))))
```

Expected exit code: 0
Expected output: -7

## Deeply nested expression tree

`((1+2)+(3+4)) * ((5+6)+(7+8))` = `10 * 26` = `260`

```scheme
(begin
  (define make-num (lambda (n) (cons "num" (cons n #nil))))
  (define make-add (lambda (a b) (cons "add" (cons a (cons b #nil)))))
  (define make-mul (lambda (a b) (cons "mul" (cons a (cons b #nil)))))
  (define arith-eval
    (gamma
      (("num" ,n) n)
      (("add" ,(a) ,(b)) (+ a b))
      (("mul" ,(a) ,(b)) (* a b))
      (("do" ,(result)) result)))
  (display (arith-eval "do"
    (make-mul
      (make-add (make-add (make-num 1) (make-num 2))
                (make-add (make-num 3) (make-num 4)))
      (make-add (make-add (make-num 5) (make-num 6))
                (make-add (make-num 7) (make-num 8)))))))
```

Expected exit code: 0
Expected output: 260
