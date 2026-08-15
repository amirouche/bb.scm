# bb (Mobius Seed) — Security & Code Audit

Date: 2026-08-15

Scope: 15 libraries under `src/bb/` (~12.3k LOC) plus `src/transparenturing.scm`
(3.2k LOC), the `bb` launcher, and the content store. Findings are prioritized
by severity.

## Critical

### C1. Arbitrary file read/write via HTTP path traversal

The store HTTP server has a direct path-traversal vulnerability that lets any
client read and (with an API key) write arbitrary files.

`src/transparenturing.scm:1952–1971` splits the URL path on literal `/`
**before** percent-decoding each segment (`:1965, :1968`). `%2e`→`.` and
`%2f`→`/` are decoded afterward, so a request like
`GET /api/store/combiners/HASH/..%2f..%2f..%2fetc%2fpasswd` becomes the path
`combiners/HASH/../../../etc/passwd`. `store-path-join` (`store.scm:77–87`) is
pure string concatenation with no `..` filtering, and `store-real-path`
(`store.scm:135–139`) is a **no-op stub** that returns its input unchanged
despite a comment claiming to resolve `.` and `..`.

- **Read:** `server.scm:188–194` serves the resulting path as
  `application/octet-stream`. No auth required on GET.
- **Write:** `server.scm:204–213` writes the PUT body to the resulting path
  after only an API-key check (`:200`). A `.wip.scm` suffix check (`:207`) is
  trivially bypassed.

The only guard on writes is `%authorized?` (`server.scm:49–55`), and it
compares the `Authorization` header with `string=?` — a non-constant-time
comparison, minor but worth noting for key extraction timing.

### C2. `xeno` is unrestricted host code execution

`evaluator.scm:282–284` — the `xeno` primitive resolves *any* Chez Scheme
binding by name via `(eval (string->symbol procedure-name))` and applies it to
attacker-controlled arguments. There is no allowlist. Any Mobius program can do
`xeno "system" "rm -rf /"`, `xeno "open-input-file" ...`, `xeno "eval" ...`.
This is the language's entire FFI surface and it is fully open. Whether this is
"by design" or a hole depends on the threat model, but it should be documented
as a deliberate, named capability rather than an unguarded primitive.

### C3. Shell injection in the `bb` launcher and CLI

The `bb` launcher builds Scheme source by string-concatenating argv:

```sh
# bb (the launcher)
args=""
for a in "$@"; do args="$args \"$a\""; done
echo "(import (bb cli)) (apply main (list $args))" | scheme --quiet --libdirs ./src/
```

Each argument is wrapped in `"..."` but **double quotes and backslashes inside
the argument are not escaped**. An argument containing `"` breaks out of the
Scheme string literal and injects code. Example:
`./bb eval 'foo" (display "pwned") "'`.

The same pattern repeats inside `cli.scm`:

- `cli.scm:1651, 1870` — `$EDITOR`/`$VISUAL` is concatenated raw into a
  `system` call (`editor " " tmp-file`). `EDITOR="vi; rm -rf /"` executes.
- `cli.scm:3071, 3075, 3079` — `ots stamp/upgrade/verify <path>` where `path`
  can contain shell metacharacters if derived from a store filename (filenames
  come from `directory-list`).
- `cli.scm:3736` — `command-serve` builds `scheme --quiet <libdirs> < tmp` from
  `(library-directories)`, which honors `CHEZSCHEMELIBDIRS`; shell
  metacharacters there inject.

## High

### H1. `eval-guard` is effectively a no-op

`evaluator.scm:801–825` — the `guard` special form computes `entry-clauses`
(`:805`) and `exit-clauses` (`:807`) but **never uses them**. The body is
evaluated with a `current-guard-entry` continuation installed, but no
`with-exception-handler`/`guard` wraps the `mobius-eval` call, so raised errors
propagate uncaught. The language's only exception construct silently fails to
guard anything.

### H2. No resource limits on the interpreter → DoS

`evaluator.scm:631` (`mobius-eval`) uses the host call stack directly with no
fuel/depth counter. Several unbounded recursion paths:

- Catamorphic `,(x)` (`pattern.scm:67–71`) re-applies the combiner to sub-values
  with **no depth limit and no cycle guard**. A non-`#nil`-terminated recursion,
  or a circular argument tree (constructible via `box!`+`cons`), overflows the
  stack. Not trampolined.
- `reader.scm:378–410` (`read-list`) and `:304–310` (datum-comment `#;`) recurse
  with no depth bound. Deeply nested input or a file of `#; #; #; ...` blows
  the stack.
- `cli.scm:119–130` (`eval`), `:212–249` (`repl`), `:1294–1337` (`run`) — no
  CPU/memory/recursion limits. `(lambda (x) (x x))` applied to itself hangs
  with no interrupt.

### H3. HTTP request parsing — unbounded memory / response splitting

`transparenturing.scm`:

- `:1674` `http-line-read` conses every byte into a list until CRLF — **no
  line-length limit**. A multi-GB header line grows the heap. The 5s read
  timeout (`:1067`) applies per 4096-byte `loop-read` chunk, not to total line
  time.
- `:1709` `http-headers-read` loops until an empty line with **no header-count
  cap**.
- `:1654, :1733` `http-body-read` allocates `(make-bytevector Content-Length)`
  upfront — `Content-Length: 9999999999` triggers a multi-GB allocation
  immediately.
- `:1715–1725` chunked body accumulation has no total-size limit.
- `:1821–1836` `http-response-write` interpolates header values with
  `string-append` and **no CRLF sanitization** — response splitting if a handler
  returns a header value containing `\r\n`.
- `:1148–1175` the CQE drain loop in `loop-run-once` has **no `guard`**; a
  foreign-call error there propagates to `loop-run` (`:1185`) which sets the
  server to stopped. Per-request errors are otherwise well-caught (`:3134,
  :3142, :1765`).

### H4. Store writes are non-atomic + TOCTOU races

`store.scm` — every write uses `call-with-output-file` directly to the final
path; no temp-file-then-rename anywhere (`:171, :189, :246, :797, :833,
:870–872, :930`). A crash mid-write leaves a truncated file. Notably,
`store-load-combiner` (`:279`) then `read`s a truncated `tree.scm`, producing
a corrupt tree that appears valid.

The immutability guarantee for `tree.scm` is racy: `store-combiner!`
(`:169–172`) does `unless (file-exists? tree-path)` then writes — a classic
TOCTOU. Two concurrent writers both pass the check and the second truncates the
first. Same pattern at `:187, :244, :263, :465, :550, :754, :962`.

No symlink checks anywhere (`:169, :89–104, :910–932, :934–944`), so a
symlinked `tree.scm` → `/etc/cron.d/x` is followed.

### H5. `file://` remotes and unsanitized remote paths

`store.scm:882–889` `store-remote-entry-path` strips a `file://` URL and uses the
remainder as a filesystem path with no normalization. `cli.scm`
`%pull-via-http!` (`:2872–2906`) writes `relpath` values that come from a
**remote server's response body** without sanitization — a malicious remote
returning `../../etc/cron.d/evil` causes a path-traversal write. Same for
`%push-via-http!` (`:2862–2867`).

## Medium

### M1. Content-hash determinism is fragile

The whole identity model rests on SHA-256 of serialized trees, but serialization
is not robust:

- `serialization.scm:72–73` — flonums written via `display`, which is
  locale/implementation-dependent (`+nan.0`, `+inf.0`, denormals). Breaks hash
  stability across hosts/Chez versions.
- `serialization.scm:76–77` — symbols written with no escaping. A symbol
  containing `(`, `)`, `"`, or spaces produces output that `read` misparses →
  **injection** if symbols come from untrusted input.
- `serialization.scm:41–54` — string escaping handles `\" \\ \n \t \r` but not
  NUL/ESC/bytes >127; raw NUL makes output unreadable.
- `serialization.scm:100–120` — `sorted-alist->string` preserves duplicate keys
  and Chez `sort` isn't guaranteed stable → non-deterministic output for alists
  with dup keys.
- No cycle/depth detection in serialization (`:23–97`) or
  `scheme-list->mobius-list` (`values.scm:278–283`, not tail-recursive).

### M2. Pervasive silent exception swallowing

14+ `guard` clauses return `#f`/`void`/`'()` with no logging. Most
consequential:

- `cli.scm:696` `load-index-into-env` silently leaves a combiner as `#void` if
  it fails to load → dependencies resolve to void at runtime with no
  diagnostic.
- `store.scm:522` `store-load-checks-for-combiner` swallows any read error on a
  lineage file → corrupt lineage silently drops checks.
- `store.scm:703, 706` `store-build-name-index` silently skips combiners/mappings
  that fail to enumerate.

### M3. Primitive index stability is fragile

`evaluator.scm:884–896` — the `primitive-names` vector (indices 0–42) is
currently append-only, but:

- The comment at `:882` ("missing exact->inexact...") signals intent to
  **insert**, which would shift indices and corrupt every stored `tree.scm`.
- Indices are hardcoded as bare integer literals in `apply-primitive`
  (`:279–555`) and `normalize-body` (`:1001, :1005, :1010, :1030, :1036, :1042,
  :1057, :1090`). No assertion ties the vector length to the max `case` index
  (42). The `make-initial-environment` magic bound `> index 42` (`:902`) is
  duplicated from the vector length and desyncs silently if the vector grows.

### M4. `read` on untrusted store data

`cli.scm:479, :1220, :2606, :2666` read mapping/lineage files with Chez's
`read`, which can instantiate arbitrary Scheme structures and, in some
configurations, reader macros. Data comes from the local store, but in
`pull`/`sync` it originates from **remote stores** (combined with H5).

### M5. Reader sentinel leaks and weak input validation

- `reader.scm:459–467` — a bare `.` at top level returns the internal
  `mobius-dot-sentinel` symbol to the caller.
- `reader.scm:255–272` — `parse-hex-string` has no overflow/bounds check;
  huge hex literals allocate enormous bignums.
- `reader.scm:449–456` — malformed floats like `+.` or `3.e` fall through to
  `string->number` producing `+nan.0` with no guard.
- `reader.scm:327–332` — `#lang <anything>` is silently accepted and ignored;
  `(#lang round)` inside a list silently drops a value.
- `values.scm:68` — `mobius-nil` is literally `'()`; no distinct null type.
  `mobius-nil?` is just `null?`, so any empty list is `#nil`. Deliberate but
  easy to misuse.

## Low

- `hash.scm` SHA-256 implementation is correct against known test vectors
  (`:225–233`), but `hash-split` (`:219–221`) is now an identity stub with a
  TODO to delete — `hash-combiner` hashes the **serialized string** (`:207–209`),
  so hash determinism depends entirely on M1.
- `environment.scm:49–50` — negative de Bruijn indices reach
  `vector-ref frame -1` (raw Chez error) instead of the intended out-of-range
  message.
- `values.scm:142–145` — mutable boxes + captured continuations retain
  aborted-continuation side effects (classic continuation+mutation bug).
- `pattern.scm:80–92` — predicate guards call `eval-procedure` on an expression
  taken directly from the pattern; if patterns are built from untrusted reader
  output, this is code execution.
- `cli.scm:3689–3702` — `%positional-args` only skips values for
  `--port`/`--api-key`; any other `--flag value` treats `value` as positional.
  `--debug`/`--all` only recognized at `car arguments` (`:1299, :1895`).
- Several primitives assume fixed arity with no checks (`evaluator.scm:222,
  :288–402, :487`) — `(cons)`, `(+ )`, `(box!)` raise raw Chez errors rather
  than Mobius-level messages.

## What's solid

- SHA-256 matches FIPS test vectors.
- Per-request error isolation in the HTTP server is mostly good
  (`transparenturing.scm:3134, :3142, :1765`).
- `store-combiner!` prevents direct overwrites of existing `tree.scm` under
  normal (single-writer) operation.
- `eval`/`repl`/`run` correctly propagate Mobius-level errors rather than
  swallowing them.

## Recommended priority for fixes

1. **C1** (path traversal via `%2f` decode-after-split + no-op
   `store-real-path`) — the highest-impact, most exploitable issue. Affects both
   read and write through the public HTTP API.
2. **C3** (shell injection in `bb` launcher and `$EDITOR`/`ots`/`libdirs`) —
   trivially exploitable locally.
3. **H1** (`eval-guard` inert) — breaks a documented language feature silently.
4. **H3** + **H2** (HTTP memory limits, interpreter fuel) — DoS hardening.
5. **H4** (atomic store writes) — data integrity.
6. **C2** (`xeno`) — decide and document the threat model; if untrusted Mobius
   code is ever run, this needs an allowlist.

## Open question

The audit assumes the HTTP store server is exposed to untrusted clients. If it
is intended to be local-only/trusted, C1 and H3 drop in severity but don't
disappear (the `%2f` decode ordering is still a latent bug). The one design
decision that could not be validated: whether `xeno`'s unrestricted host access
is an intentional, documented capability or an oversight. That determines
whether C2 is a bug or a feature needing a warning.
