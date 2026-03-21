# Advanced Pattern Matching

Testing complex gamma patterns, predicate guards, and nested matching.

## Multi-argument gamma

```scheme
(begin
  (define classify
    (gamma
      ((0) "zero")
      ((1) "one")
      ((,n) "other")))
  (display (classify 0))
  (display " ")
  (display (classify 1))
  (display " ")
  (display (classify 42)))
```

Expected exit code: 0
Expected output: zero one other

## Nested pair destructuring

```scheme
(begin
  (define first-of-pair
    (gamma
      (((,a . ,_) . ,_) a)))
  (display (first-of-pair (cons 1 2) (cons 3 4))))
```

Expected exit code: 0
Expected output: 1

## Predicate guard

```scheme
(begin
  (define abs-val
    (gamma
      (((? integer? ,x)) (if (< x 0) (- 0 x) x))))
  (display (abs-val 5))
  (display " ")
  (display (abs-val -3)))
```

Expected exit code: 0
Expected output: 5 3

## Wildcard patterns

```scheme
(begin
  (define second
    (gamma
      ((,_ ,x . ,_) x)))
  (display (second 10 20 30 40)))
```

Expected exit code: 0
Expected output: 20

## Multiple clauses with fallthrough

```scheme
(begin
  (define describe
    (gamma
      ((0 0) "origin")
      ((,x 0) "x-axis")
      ((0 ,y) "y-axis")
      ((,x ,y) "plane")))
  (display (describe 0 0))
  (display " ")
  (display (describe 5 0))
  (display " ")
  (display (describe 0 3))
  (display " ")
  (display (describe 2 7)))
```

Expected exit code: 0
Expected output: origin x-axis y-axis plane

## Catamorphic flatten

```scheme
(begin
  (define sum-nested
    (gamma
      ((,head . ,(tail)) (+ head tail))
      (#nil 0)))
  (display (sum-nested 10 20 30)))
```

Expected exit code: 0
Expected output: 60

## String pattern matching

```scheme
(begin
  (define greet
    (gamma
      (("hello" ,name)
       (begin (display "Hi ") (display name) (display "!")))
      ((,_ ,_)
       (display "???"))))
  (greet "hello" "world"))
```

Expected exit code: 0
Expected output: Hi world!
