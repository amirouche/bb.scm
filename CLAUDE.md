# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

bb (Mobius Seed) is a content-addressed programming language and knowledge store written in Chez Scheme (R6RS). It separates code identity (logic hashed via SHA-256 after de Bruijn normalization) from presentation (variable names, language), enabling multilingual programming with authorship/lineage tracking.

## Running

Requires Chez Scheme (`scheme` on PATH).

```bash
# Run the CLI
./bb <command> [args...]

# Evaluate Mobius expressions
./bb eval '(+ 1 2)'

# Start a REPL
./bb repl

# Run arbitrary Scheme with bb libraries
echo '(import (bb evaluator)) (display "hi")' | scheme --quiet --libdirs ./src/
```

## Testing

Tests are `~check-*` procedures exported from each library. Run a single test:

```bash
echo '(import (bb values)) (~check-values-nil)' | scheme --quiet --libdirs ./src/
```

Run a transcript test (must be run from `src/tests/` or with `--libdirs` so transcript-path resolves):

```bash
echo '(import (bb transcript)) (~check-transcript-basics)' | scheme --quiet --libdirs ./src/ --source-directories ./src/tests/
```

Transcript tests are Markdown files in `src/tests/` with fenced code blocks, expected exit codes, and expected output. There is no Makefile or test runner script — invoke check procedures directly.

## Architecture

### Source layout

All libraries live under `src/bb/` as R6RS `(library (bb <name>) ...)` forms:

- **evaluator.scm** — Tree-walking interpreter. Evaluates atoms, symbols, special forms (gamma, lambda, if, and, or, begin, define, guard). Application builds an argument tree, pattern-matches against combiner clauses, and evaluates the body.
- **reader.scm** — S-expression reader. Hash identifiers (`#nil`, `#true`, `#false`, `#void`, `#eof`), pattern syntax (`,x` bind, `,(x)` catamorphic bind, `,_` wildcard, `(? pred ,x)` predicate guard), `#lang round` directive.
- **values.scm** — Mobius value types: integers, floats, chars, strings, booleans, pairs, boxes, capsules, continuations, combiners, primitives.
- **pattern.scm** — Pattern matching for gamma clause selection. Binds at de Bruijn indices (0 = self, 1+ = pattern variables).
- **environment.scm** — De Bruijn indexed vector-based frames for evaluator environments.
- **hash.scm** — Pure Scheme SHA-256 for content addressing.
- **store.scm** — File-based content store. Combiners stored in `combiners/<sha256>/tree.scm` with mappings in `mappings/<hash>/map.scm`. Handles lineage, worklog, config, review marks.
- **serialization.scm** — Deterministic value-to-string serialization.
- **cli.scm** — CLI commands: eval, repl, add, commit, edit, diff, refactor, resolve, review, search, worklog, validate, anchor, mapping, remote, run, status, show, print, tree, caller, check, log, store (init/info).
- **base-library.scm** — Standard library written in Mobius (list, not, equal?, capsule ops). Installed into environment at startup.
- **z3.scm** — SMT solver integration for symbolic property verification.
- **transcript.scm** — Markdown-based test runner: parses fenced blocks, runs them, compares exit codes and output.
- **match.scm** — SRFI 241 pattern matching (used internally, not for gamma).

### Content store layout

```
config.scm              — author metadata, remotes
combiners/<sha256>/
  tree.scm              — immutable normalized AST
  mappings/<hash>/
    map.scm             — language-specific name/metadata
  lineage/
    <hash>.wip.scm      — work-in-progress lineage
reviewed/               — attestations of reviewed combiners
worklog/                — timestamped work entries
```

### Key concepts

- **Gamma** is the primary abstraction — catamorphic pattern-matching combiners. `,(x)` auto-recurses on sub-expressions; this replaces explicit recursion.
- **De Bruijn normalization** erases variable names to positional indices (0 = self-reference). Same logic always produces the same SHA-256 hash regardless of naming language.
- **Mappings** store human-readable names per language alongside the hash-addressed normalized tree.

## Critical constraints

- **Never renumber primitives.** The `primitive-names` vector in `evaluator.scm` assigns permanent indices (0=gamma, 1=lambda, 2=xeno, ...). These indices are baked into stored combiner hashes. Only append new primitives at the end.
- **Append-only store.** Combiners are immutable once hashed. Retractions are new entries with derivation chains.
- **Never delete `combiners/`.** The `combiners/` directory is the content store — it contains all registered combiner data (trees, mappings, lineage). Never delete, move, or modify files under `combiners/` unless the user explicitly instructs it. If something seems wrong with the store (corruption, unexpected state, test failures involving stored data), stop and ask the user for guidance rather than attempting destructive fixes.
