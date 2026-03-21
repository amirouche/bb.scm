# Recursion

Self-recursion via gamma and mutual recursion via define pre-binding.

## Factorial

Gamma with self-recursion: the combiner calls itself by name.

```scheme
(begin
  (define factorial
    (gamma
      ((0) 1)
      ((,n) (* n (factorial (- n 1))))))
  (display (factorial 10)))
```

Expected exit code: 0
Expected output: 3628800

## Fibonacci

```scheme
(begin
  (define fib
    (gamma
      ((0) 0)
      ((1) 1)
      ((,n) (+ (fib (- n 1)) (fib (- n 2))))))
  (display (fib 10)))
```

Expected exit code: 0
Expected output: 55

## Catamorphic sum

The `,(tail)` syntax applies the enclosing gamma to the rest of the
list — no explicit recursive call needed.

```scheme
(begin
  (define sum
    (gamma
      ((,head . ,(tail)) (+ head tail))
      (#nil 0)))
  (display (sum 1 2 3 4 5)))
```

Expected exit code: 0
Expected output: 15

## Catamorphic product

```scheme
(begin
  (define product
    (gamma
      ((,head . ,(tail)) (* head tail))
      (#nil 1)))
  (display (product 1 2 3 4 5)))
```

Expected exit code: 0
Expected output: 120

## Catamorphic length

```scheme
(begin
  (define length
    (gamma
      ((,_ . ,(rest)) (+ 1 rest))
      (#nil 0)))
  (display (length 10 20 30 40)))
```

Expected exit code: 0
Expected output: 4

## Mutual recursion

`my-even?` and `my-odd?` call each other. Both are defined in the same
`begin` block; the evaluator pre-binds all names before evaluating any
definition, so forward references work.

```scheme
(begin
  (define my-even?
    (gamma
      ((0) #true)
      ((,n) (my-odd? (- n 1)))))
  (define my-odd?
    (gamma
      ((0) #false)
      ((,n) (my-even? (- n 1)))))
  (display (my-even? 10))
  (display " ")
  (display (my-odd? 7)))
```

Expected exit code: 0
Expected output: #true #true

## GCD

Uses repeated subtraction since Möbius lacks integer modulo.

```scheme
(begin
  (define gcd
    (gamma
      ((,a 0) a)
      ((0 ,b) b)
      ((,a ,b)
       (if (> a b)
           (gcd (- a b) b)
           (gcd a (- b a))))))
  (display (gcd 48 18)))
```

Expected exit code: 0
Expected output: 6
