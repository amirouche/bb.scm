# Roadmap — Möbius Seed Evaluator (South)

*Gap analysis between R0RM (Draft 6) + Personas and the current implementation.*

Last updated: April 2026

---

## Status at a Glance

| Area | Spec | Implemented | Gap |
|------|------|-------------|-----|
| Round surface | §3.2 | Full | — |
| Curly surface | §3.3 | — | Reader, printer |
| Spacy surface | §3.4 | — | Reader, printer |
| Values (8 categories) | §2 | Full | — |
| Gamma + catamorphism | §4 | Full | — |
| Patterns | §5 | Full | Bare-identifier rejection (§5.2) |
| Lambda | §8 | Full | — |
| Capsules | §9 | Full | — |
| Boxes | §10 | Full | — |
| Continuations | §12 | Partial | Guard entry/exit (§12.3), `continuation-exit` (§12.4) |
| Foundations (~34) | §14.1 | 35 primitives | `continuation-apply` naming, guard form |
| Base library | §14.2 | 5 of 8 | `continuation-extend`, `error` missing |
| Content store | §1.1 | Full | — |
| Naming / mappings | §1.2 | Full | — |
| Registration pipeline | §1.3 | Partial | Name→hash resolution, DAG enforcement |
| CLI commands | Personas | 17 commands | `bb check`, `bb refactor`, `bb anchor` |
| Tests | — | 47+ | — |
| Transcripts | — | 2 | — |

---

## 1. Language Completeness

### 1.1 Guard — full form (§12.3)

**Spec says:** `guard` installs entry and exit gamma clauses on a continuation boundary — pattern-matching handlers for abnormal passes in both directions, subsuming `dynamic-wind` and exception handling.

**Today:** A simplified `(guard (type handler) expr)` form exists. Entry/exit gamma clause structure is not implemented.

**Needed:** Rewrite guard to accept `(guard (entry clause...) thunk (exit clause...))` with proper continuation boundary semantics.

### 1.2 continuation-exit (§12.4)

**Spec says:** `continuation-exit` is a well-known binding — the root continuation. Delivering a value (integer 0–255) to it terminates the program. Guards installed between the current point and the root are traversed.

**Today:** Not exposed. The evaluator exits via Chez Scheme's `exit` or `call/cc` escape, but `continuation-exit` is not available as a named binding in the Möbius environment.

**Needed:** Bind `continuation-exit` in the initial environment as the root continuation. Implement proper traversal of guard boundaries on exit.

### 1.3 continuation-extend (§14.2)

**Spec says:** Base library combiner built from `call/cc` and `continuation-apply`. Takes a continuation and a combiner, returns a composed continuation.

**Today:** Not implemented.

**Needed:** Write in Möbius once `continuation-apply` and `call/cc` are solid, install via `base-library.scm`.

### 1.4 error (§14.2)

**Spec says:** Base library combiner. Takes an exit code, a message string, and a tree. Displays the message and tree, then delivers the exit code to `continuation-exit`.

**Today:** Not implemented. Errors currently go through Chez Scheme's exception system or `assume`.

**Needed:** Write in Möbius, install via `base-library.scm`. Depends on `continuation-exit`.

### 1.5 Bare-identifier rejection in patterns (§5.2)

**Spec says:** Bare identifiers in patterns are forbidden. The registrar rejects them.

**Today:** The reader converts `,x` to bind forms, but a bare `x` in pattern position may silently be treated as a symbol reference rather than rejected.

**Needed:** Validate during normalization/registration that no bare identifiers appear in pattern position. Emit a clear error.

### 1.6 Anonymous combiner restriction (§3.2)

**Spec says:** Every `gamma` or `lambda` must be bound to a name via `define`. No anonymous combiners as arguments. This ensures surface equivalence across round, curly, and spacy.

**Today:** Not enforced. Anonymous `(gamma ...)` and `(lambda ...)` can be passed as arguments freely.

**Needed:** Enforce at registration time. The evaluator in REPL/eval mode may allow it for convenience, but `bb add` should reject it.

### 1.7 .mobius extension and #lang declaration (§3.1)

**Spec says:** Source files use `.mobius` extension and begin with `#lang round`, `#lang curly`, or `#lang spacy`.

**Today:** Files use `.scm`. The reader does not process `#lang` declarations (it reads `#lang` as a hash-identifier).

**Needed:** Support `.mobius` files. Parse `#lang` as a surface selector. Keep `.scm` support for backward compatibility.

---

## 2. Surfaces

### 2.1 Curly surface (§3.3)

**Spec says:** Braces and semicolons. Infix arithmetic with mandatory full parenthesization. `case` keyword for gamma clauses. `//` line comments.

**Today:** Not implemented.

**Needed:** A curly reader (lexer + parser) producing the same internal tree as round. A curly printer for `bb show`. Infix→prefix translation with mandatory parenthesization (no precedence).

### 2.2 Spacy surface (§3.4)

**Spec says:** Indentation and colons. Same infix rules. `#` line comments. INDENT/DEDENT tokens.

**Today:** Not implemented.

**Needed:** A spacy reader with indentation tracking. A spacy printer. Same internal tree as round and curly.

### 2.3 Infix evaluation (§6.4)

**Spec says:** `(a op b)` in curly/spacy is translated to `(op a b)`. No operator precedence — unparenthesized `a + b * c` is a reader error.

**Today:** Not applicable (no curly/spacy reader).

**Needed:** Part of curly/spacy reader implementation. Detect and reject unparenthesized infix chains.

### 2.4 Surface equivalence verification

**Spec says (§3.7):** The same definition in round, curly, and spacy produces the same content hash.

**Needed:** Once all three readers exist, a test suite that verifies identical hashes across surfaces for a corpus of definitions.

---

## 3. Content Model & Store

### 3.1 Full registration pipeline (§1.3)

**Spec says:** Parse → resolve names against name index → replace names with hashes → compute hash → store tree → store mapping. After registration, no free names remain — only hashes.

**Today:** `bb add` parses, normalizes to de Bruijn indices, hashes, and stores. But references to other combiners are not resolved to content hashes at registration time — the surface evaluator uses name-based lookup.

**Needed:** During `bb add`, resolve each free name to its content hash in the store. Reject unresolved names. Store the tree with hash references, not names. This is the transition from "interpreter" to "content-addressed repository."

### 3.2 Dependency DAG enforcement (§1.3, §7.3)

**Spec says:** Definition A may reference B only if B is already registered. The dependency graph is strictly a DAG. No top-level mutual recursion (§16.9).

**Today:** Not enforced. The evaluator resolves names dynamically.

**Needed:** At registration time, verify that every referenced combiner already exists in the store. Reject forward references.

### 3.3 bb check — check suites (Personas: Coordinator)

**Spec says:** Check suites define what "correct" means. `bb check HASH` runs a combiner against its associated checks. Central to the Coordinator role, the Maintainer's verification step, and ZKP attestation.

**Today:** `store-load-checks` and `store-load-checks-for-combiner` exist in store.scm but are stubs or partial. No `bb check` CLI command.

**Needed:** Define the check suite format (predicates that a correct solution must satisfy). Implement `bb check` to run checks against a combiner and report pass/fail. Store check results.

### 3.4 bb refactor — path propagation (Personas: Maintainer)

**Spec says:** `bb refactor name old-hash new-hash` updates paths — rewires which names point to which hashes. Selective propagation through dependents.

**Today:** Not implemented.

**Needed:** Implement `bb refactor` that updates naming references from old hash to new hash across dependent combiners. Requires the full registration pipeline (§3.1) to rewrite hash references.

### 3.5 derived-from lineage (Personas: Forker)

**Spec says:** `bb commit` with `derived-from` and a `relation` field. Relations: fork, fix, refine, extend, rewrite. Makes derivation explicit and permanent.

**Today:** Lineage records exist (WIP + committed) but lack a `derived-from` field or `relation` enum.

**Needed:** Extend lineage record format to include optional `derived-from` hash and `relation`. Surface in `bb commit`, `bb log`, `bb show`.

### 3.6 bb search --near (Personas: Curator, Forker)

**Spec says:** Structural similarity detection using SimHash or equivalent over de Bruijn trees. At commit time, similar existing hashes are surfaced as a prompt. Central to the Forker's accountability and the Curator's pattern recognition.

**Today:** `bb search` does name-based substring matching. No structural similarity.

**Needed:** Implement a SimHash or tree-edit-distance metric over de Bruijn normalized trees. Add `--near` flag to `bb search`. Optionally prompt at `bb commit` time when near-matches exist.

### 3.7 bb anchor — OpenTimestamps (§1.6)

**Spec says:** `bb anchor` requests a Bitcoin-anchored timestamp proof via OpenTimestamps. Priority is cryptographic, not local. Content stays local until explicitly pushed.

**Today:** Not implemented. Timestamps are local ISO 8601 strings.

**Needed:** Integrate with OpenTimestamps (ots CLI or library). Store OTS proofs alongside lineage records. Implement `bb anchor` command. Implement OTS verification in `bb validate`.

### 3.8 Sealed timestamps (§1.6)

**Spec says:** A combiner can be committed and timestamped without disclosure. The hash is public; the content is local. "Dark matter" in the store.

**Today:** All committed content is stored locally but the concept of "sealed vs. disclosed" is not tracked.

**Needed:** Add a sealed/disclosed flag to lineage records. Allow `bb commit --sealed` to record the hash and timestamp without requiring the content to be pushable.

### 3.9 Store modes (§16.5)

**Spec says:** Local-only, federated, centralized store modes for naming layer discovery and composition.

**Today:** Local store only. `bb remote` exists but federation model is basic.

**Needed:** Design and implement store federation — how multiple stores compose their name indices, handle conflicts, and discover content across boundaries.

---

## 4. CLI & Role Workflows

### 4.1 bb review — DAG walk (Personas: Reviewer)

**Spec says:** `bb review <identifier>` walks a dependency DAG interactively, marking each hash as reviewed or not. Attestations accumulate in `reviewed/`.

**Today:** `bb review HASH` marks a single hash as reviewed. No interactive DAG walk.

**Needed:** Implement interactive DAG traversal — show each dependency, allow mark/skip, accumulate review state.

### 4.2 bb review --status (Personas: Maintainer)

**Spec says:** After `bb refactor`, `bb review --status` shows which new hashes have no attestations yet. Trust resets with content.

**Today:** Not implemented.

**Needed:** Compare hashes in a dependency chain against the review store. Surface unreviewed hashes.

### 4.3 bb edit identifier@lang (Personas: Author, Forker)

**Spec says:** `bb edit identifier@lang` opens a working session from an existing hash in a specific language mapping.

**Today:** `bb edit HASH` opens in `$EDITOR`. Language-specific opening via `@lang` suffix exists but may need polish.

**Needed:** Verify and polish the `@lang` workflow. Ensure the edited content re-registers correctly with the same language mapping.

---

## 5. Open Questions (§16)

These are acknowledged in the spec as unresolved. They represent longer-term research and design work.

| # | Question | Spec | Notes |
|---|----------|------|-------|
| 1 | Predicate inference | §16.1 | Compiler infers predicates from foundation signatures and gamma clause structure. Formal mechanism TBD. |
| 2 | Effects | §16.2 | `raise`, `raise-continuable`, coroutines as named patterns over guard/call/cc. Definitions TBD. |
| 3 | eval semantics | §16.3 | `integer->combiner` — hash lookup + execution. Security implications open. |
| 4 | Error model | §16.4 | What happens on gamma mismatch, `car` of atom, division by zero. Likely capsule-based error values raised via `continuation-apply`. |
| 5 | Concurrency | §16.6 | CSP channels. Interaction with boxes and continuations. |
| 6 | Cycle detection | §16.7 | `equal?` on self-referential boxes is undefined behavior. Should detection be required? |
| 7 | I/O model | §16.8 | Only `display` exists. File handles, network, OS resources unspecified. |
| 8 | Mutual recursion | §16.9 | Top-level mutual recursion via registrar bundling. Stale reference handling. |
| 9 | Type ID derivation | §16.10 | How to choose capsule type IDs to avoid collisions. Deterministic derivation scheme. |
| 10 | ZKP format | §16.11 | Proof system choice, verification without content, proof size scaling. |
| 11 | Oblivious execution | §16.12 | Runtime privacy. ORAM/TEE/MPC integration. Orthogonal to Möbius but enabled by its infrastructure. |
| 12 | Ellipsis patterns | Annex A | `...` for zero-or-more repetitions. Depth tracking. Orthogonal to catamorphism. |

---

## 6. Test Coverage Gaps

Current tests cover the language core well. Missing test coverage for:

- Guard with entry/exit clauses (once implemented)
- `continuation-exit` and `error` (once implemented)
- Registration pipeline: name→hash resolution round-trip
- `bb check` end-to-end
- `bb refactor` end-to-end
- `derived-from` lineage recording and display
- Surface equivalence (round = curly = spacy hashing)
- Bare-identifier rejection in patterns
- Anonymous combiner rejection at registration time

---

## Suggested Priority Order

**Near-term — complete the seed evaluator:**
1. Guard full form (§1.1)
2. `continuation-exit` + `error` (§1.2, §1.4)
3. `continuation-extend` (§1.3)
4. Bare-identifier rejection in patterns (§1.5)
5. `derived-from` lineage (§3.5)
6. `bb check` (§3.3)

**Medium-term — content-addressed registration:**
7. Full registration pipeline with hash references (§3.1)
8. Dependency DAG enforcement (§3.2)
9. `bb refactor` (§3.4)
10. Anonymous combiner restriction (§1.6)
11. `.mobius` + `#lang` support (§1.7)

**Longer-term — surfaces and infrastructure:**
12. Curly surface reader + printer (§2.1)
13. Spacy surface reader + printer (§2.2)
14. `bb search --near` / SimHash (§3.6)
15. `bb anchor` / OpenTimestamps (§3.7)
16. Store federation (§3.9)
17. Error model (§16.4)
18. I/O model (§16.8)

**Research — open questions:**
19. Predicate inference, effects, concurrency, ZKP, oblivious execution (§5)
