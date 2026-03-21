# Triple Evolution — iterative refinement of a combiner

Each version of triple is defined, stored, and shown in sequence.

## Setup store with double and first triple

```bash
rm -rf /tmp/bb-test-triple-evo
bb store init /tmp/bb-test-triple-evo > /dev/null 2>&1
cd /tmp/bb-test-triple-evo
echo '(define double (lambda (a) (+ a a)))' | bb add - > /dev/null 2>&1
echo '(define triple (lambda (a) (+ a a a)))' | bb add - > /dev/null 2>&1
bb show triple
```

Expected exit code: 0
Expected output: (define triple (lambda (a) (+ a a a)))

## Refine triple to use double

```bash
cd /tmp/bb-test-triple-evo
echo '(define triple (lambda (a) (+ (double a) a)))' | bb add --derived-from=triple --relation=refine - > /dev/null 2>&1
bb show triple@9dcc5a
```

Expected exit code: 0
Expected output: (define triple (lambda (a) (+ (double a) a)))

## Refine triple to multiply

```bash
cd /tmp/bb-test-triple-evo
echo '(define triple (lambda (a) (* 3 a)))' | bb add --derived-from=triple --relation=refine - > /dev/null 2>&1
bb show triple@bc633b
```

Expected exit code: 0
Expected output: (define triple (lambda (a) (* 3 a)))

## All three versions visible in status

```bash
cd /tmp/bb-test-triple-evo
bb status 2>&1 | grep -c triple
```

Expected exit code: 0
Expected output: 3

## Clean up

```bash
rm -rf /tmp/bb-test-triple-evo
```

Expected exit code: 0
