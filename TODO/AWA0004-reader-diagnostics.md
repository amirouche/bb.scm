Number: AWA0004
Title: Reader and normalize diagnostics need source positions
Status: todo

## Abstract

Give `mobius-read` and `normalize` actionable diagnostics: line and
column on reader errors ("unterminated list" currently has none), and
structural linting for the mis-nesting class of errors that normalize
accepts silently today.

## Context

Two independent losses in the turtle run:

- The orchestrator staged a file with a closing paren missing mid-file
  and got "Exception in mobius-read: unterminated list" — no file, no
  line, no position. Because the file balanced at EOF after a second
  error elsewhere, locating it took a hand-rolled depth audit.
- agent-runner wrote a form where an application closed before its
  argument and the final call became a dangling body element. It read,
  normalized, and staged cleanly — a broken combiner entered the store
  and only `bb check` caught it behaviorally (returned `#void`).

Paren-balance checking proved insufficient twice: balance is neither
necessary nor sufficient for correct nesting.

## Description

- Reader: thread source positions through `mobius-read` so errors
  report line and column (and the surrounding form) — "unterminated
  list starting at line 41, column 38".
- `bb add` pre-flight: after reading, report the boundary structure of
  top-level forms (how many defines, where each closes) or reject
  input whose top-level define count differs from the file's intent
  where detectable.
- Normalize lint: flag body shapes that are statistically wrong — a
  lambda body whose last expression is an application of a bare symbol
  bound to a combiner with a mismatched arity is one signal; a top-level
  define swallowing following defines as body elements is the observed
  failure. Start with warnings, not rejections.

## Proposals

1. Positions in reader errors first (mechanical, unambiguous value),
   then normalize warnings for dangling-body shapes.
2. A `bb lint <file>` command instead of automatic warnings — keeps
   `bb add` quiet but gives agents the audit the orchestrator had to
   write by hand.
3. Do nothing — checks already catch everything behaviorally —
   rejected: the cost shows up as agent debugging time and broken trees
   committed to the store.
