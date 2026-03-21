# Möbius Language Basics

Core language features: arithmetic, booleans, conditionals, and string literals.

## Integer arithmetic

```scheme
(display (+ 3 7))
```

Expected exit code: 0
Expected output: 10

## Nested arithmetic

```scheme
(display (* (+ 2 3) (- 10 4)))
```

Expected exit code: 0
Expected output: 30

## Boolean not

```scheme
(begin
  (define not (gamma ((#false) #true) ((,_) #false)))
  (display (not #false)))
```

Expected exit code: 0
Expected output: #true

## If expression

```scheme
(display (if #true 42 0))
```

Expected exit code: 0
Expected output: 42

## If with false

```scheme
(display (if #false 42 0))
```

Expected exit code: 0
Expected output: 0

## String literal

```scheme
(display "hello world")
```

Expected exit code: 0
Expected output: hello world

## Cons, car, cdr

```scheme
(begin
  (display (car (cons 1 2)))
  (display " ")
  (display (cdr (cons 1 2))))
```

Expected exit code: 0
Expected output: 1 2

## Equality

```scheme
(begin
  (display (= 42 42))
  (display " ")
  (display (= 42 0)))
```

Expected exit code: 0
Expected output: #true #false
