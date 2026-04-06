# Z3 Lexicographic Comparison — proving packing equivalence

Two ways to compare `(tier, score)` pairs lexicographically:

The **safe, slow** way branches on tier first, then score:

```scheme
(lambda (tier1 score1 tier2 score2)
  (if (< tier1 tier2) #true
      (if (= tier1 tier2) (< score1 score2)
          #false)))
```

The **clever, fast** way packs both into one integer and does a single comparison:

```scheme
(define pack (lambda (tier score) (+ (* tier 1000) score)))

(lambda (tier1 score1 tier2 score2)
  (< (pack tier1 score1) (pack tier2 score2)))
```

The packing trick only works when scores fit in the multiplier's range.
If `score >= 1000`, the packed value bleeds into the next tier: `tier=1,
score=1001` packs to `2001`, which beats `tier=2, score=0` at `2000` —
wrong, because tier 2 should always win.

We use Z3 to prove this precisely.

## Setup

```bash
rm -rf /tmp/bb-z3-lexico
bb store init /tmp/bb-z3-lexico > /dev/null 2>&1
cd /tmp/bb-z3-lexico
echo ok
```

Expected exit code: 0
Expected output: ok

## Add the safe, slow comparator

```bash
cd /tmp/bb-z3-lexico
cat <<'EOF' | bb add -
(define slow-compare
  (lambda (tier1 score1 tier2 score2)
    (if (< tier1 tier2) #true
        (if (= tier1 tier2) (< score1 score2)
            #false))))
EOF
```

Expected exit code: 0

## Add the pack helper and fast comparator

```bash
cd /tmp/bb-z3-lexico
cat <<'EOF' | bb add -
(define pack
  (lambda (tier score) (+ (* tier 1000) score)))
EOF
cat <<'EOF' | bb add -
(define fast-compare
  (lambda (tier1 score1 tier2 score2)
    (< (pack tier1 score1) (pack tier2 score2))))
EOF
```

Expected exit code: 0

## Runtime sanity checks

```bash
cd /tmp/bb-z3-lexico
bb eval '(slow-compare 1 50 2 10)'
bb eval '(fast-compare 1 50 2 10)'
```

Expected exit code: 0
Expected output:
#true
#true

## Z3 universal check: bounded scores prove equivalence

The packing trick is equivalent to the safe approach when scores
are in `[1, 999]` and tiers are positive.

```bash
cd /tmp/bb-z3-lexico
cat <<'EOF' | bb add -
;; For all valid inputs, fast-compare = slow-compare.
(define ~check-bounded-equivalence
  (lambda (f)
    (lambda (t1 s1 t2 s2)
      (begin
        (assume (> t1 0))
        (assume (> t2 0))
        (assume (> s1 0))
        (assume (< s1 1000))
        (assume (> s2 0))
        (assume (< s2 1000))
        (assume (= (f t1 s1 t2 s2)
                   (slow-compare t1 s1 t2 s2)))))))
EOF
```

Expected exit code: 0

```bash
cd /tmp/bb-z3-lexico
bb add --check fast-compare bounded-equivalence
```

Expected exit code: 0

```bash
cd /tmp/bb-z3-lexico
bb check fast-compare 2>&1 | head -4
```

Expected exit code: 0
Expected output: Z3-PASS

## Z3 universal check: unbounded scores break packing

Without the score bound, Z3 finds a counterexample.

```bash
cd /tmp/bb-z3-lexico
cat <<'EOF' | bb add -
;; Without bounds, the packing trick fails.
(define ~check-unbounded-equivalence
  (lambda (f)
    (lambda (t1 s1 t2 s2)
      (assume (= (f t1 s1 t2 s2)
                 (slow-compare t1 s1 t2 s2))))))
EOF
bb add --check fast-compare unbounded-equivalence
bb check fast-compare 2>&1 | grep Z3-FAIL
```

Expected exit code: 1
Expected output: Z3-FAIL

## Z3 existential check: find a divergence witness

```bash
cd /tmp/bb-z3-lexico
cat <<'EOF' | bb add -
;; Find concrete inputs where they disagree.
(define ~check-find-divergence
  (lambda (f)
    (lambda (t1 s1 t2 s2)
      (begin
        (assume (> t1 0))
        (assume (> t2 0))
        (not (= (f t1 s1 t2 s2)
                (slow-compare t1 s1 t2 s2)))))))
EOF
bb add --check fast-compare find-divergence
bb check fast-compare 2>&1 | grep Z3-PASS
```

Expected exit code: 1
Expected output: Z3-PASS

## Clean up

```bash
rm -rf /tmp/bb-z3-lexico
```

Expected exit code: 0
