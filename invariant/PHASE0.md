# Phase 0 spike findings — The Invariant

Three load-bearing mechanisms validated before building the generator.

## 0a — xeno I/O works in the imperative form

A Chez output port returned by `(xeno "open-output-file" path)` survives being
held as a Möbius value across two more xeno calls (`put-string`, `close-output-port`).
Möbius values are untyped at the runtime layer, so the Chez port flows through
nested-define bindings without inspection.

**Rejected:** `(xeno "with-output-to-file" path thunk)` — `xeno` calls Chez's
`apply` on the arguments, and a Möbius `lambda` is a `<mobius-combiner>`
record, not a Chez procedure. Use the imperative open/put/close form.

**Adopted shape (used by `write-file` in `src/io/`):**

```scheme
(define write-file
  (lambda (path contents)
    (begin
      (xeno "system" (string-append "rm -f " path))   ; replace semantics
      (define port (xeno "open-output-file" path))
      (xeno "put-string" port contents)
      (xeno "close-output-port" port))))
```

For `mkdir -p`, use `(xeno "system" (string-append "mkdir -p " path))`.

## 0b — same-hash registration across three languages

Adding `identity.{en,fr,es}.scm` with translated identifiers and identical
structure produces:

- one `combiners/<hash>/` directory,
- three `combiners/<hash>/mappings/<...>/` subdirectories (one per language),
- the name `identity` (preferred-lang = first entry of `(languages ...)` in
  `config.scm`, here `en`) in the name index.

**Architectural caveat:** `store-build-name-index` (`store.scm:666`) registers
*one* name per combiner — the preferred-language one. So `bb run identity`
works, but `bb run identite` returns "combiner not found" — the French name
is on disk in `mappings/` but not in the name index. The alternate-language
mappings are visible via:

- `bb show identity@fr` — renders the French source,
- `bb show identity@es` — renders the Spanish source,
- `bb resolve identity` — lists all three mappings.

For The Invariant: every user invokes `bb run <preferred-name>` from their own
config. The store carries all three mappings; the *view* is per-user. This is
consistent with manual §22 ("Names are views into content-addressed mappings").

## 0c — pure-Möbius string-append is fast enough

A 30-fragment HTML document (~700 B) built via nested `str-append` (which
allocates char lists and rebuilds them per concat) renders in **0.31 s wall
clock** end-to-end through `bb run`, almost all of which is interpreter
startup. The actual render is sub-millisecond. At 90 posts × ~2 KB each
this stays well under a minute. **No list-of-strings IR refactor needed.**

`mob-append` and `str-append` are the only helpers required for the render
pipeline; `string-join`, `escape-html`, and `number->string` follow the same
pattern.

## Spike artifacts

The store now contains the spike combiners (`spike-system`, `spike-port`,
`spike-render`, `mob-append`, `str-append`, `render-1`, `identity`). The
store is append-only, so they remain. They are unreferenced by Phase 1 work
beyond `mob-append` and `str-append`, which we will keep and re-add under
their three-language mappings.

## Phase 2 addendum — stale manifest name resolution

When Phase 1 manifests (2 posts each) were updated to Phase 2 manifests (30
posts each), the old combiner hashes were still registered under the same
name. `store-load-preferred-mapping` resolves ties between same-language
mappings by alphabetical hash order — so the Phase 1 hash (alphabetically
earlier) would win and the generator kept producing 2-post output.

**Fix applied:** `bb mapping delete <name>@<lang>@<mapping-hash>` removes the
stale name mapping from each old combiner. Then re-add `manifest.scm` and
`generate.*.scm` so they compile against the new hash. The old combiner trees
remain in the store (append-only), but their names no longer appear in the
index.

**Lesson:** In the bb store, re-adding a changed combiner does not atomically
update the name index. The new hash is registered under the same name, creating
an ambiguity that resolves by alphabet. Explicitly delete old name mappings
when updating a load-bearing combiner across a regeneration cycle.
