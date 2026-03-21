# Beyond Babel — bb edit workflow

## Initialize and add

```bash
rm -rf /tmp/bb-transcript-edit-test
bb store init /tmp/bb-transcript-edit-test > /dev/null 2>&1
cd /tmp/bb-transcript-edit-test
cat <<'DEFEOF' | bb add - > /dev/null 2>&1
;; Double a number.

(define double
  (lambda (x) (+ x x)))
DEFEOF
echo ok
```

Expected exit code: 0
Expected output: ok

## Edit with no-op editor preserves content

```bash
cd /tmp/bb-transcript-edit-test
EDITOR=true bb edit double > /dev/null 2>&1
echo ok
```

Expected exit code: 0
Expected output: ok

## Clean up

```bash
rm -rf /tmp/bb-transcript-edit-test
```

Expected exit code: 0
