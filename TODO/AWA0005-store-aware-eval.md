Number: AWA0005
Title: Make bb eval store-aware and fix launcher argument passing
Status: todo

## Abstract

`bb eval` installs only the base library — committed combiners do not
resolve in it — and the example launcher scripts quote arguments
naively, so a literal `"` in an eval expression breaks the reader.
Make eval resolve the current store's committed combiners and give the
launchers robust argument passing.

## Context

Three agents in the turtle run independently hit both issues:

- The launcher wraps each argument in double quotes without escaping:
  any expression containing a string literal splits the generated
  Scheme code and the reader fails with "unterminated list" or
  "variable b is not bound".
- `bb eval` cannot see the store: agents had to verify language facts
  by reading committed sources instead of probing, and agent-racer2
  validated parse logic via self-application because eval could not
  load committed combiners.

The result: the cheapest verification tool in the workflow (evaluate
an expression against the store) is effectively unavailable, which
pushes agents toward scratch-store adds for every probe.

## Description

- `bb eval`: build the initial environment from the current store
  (resolve names to committed hashes the way `serve` does), falling
  back to the plain base library outside a store.
- Launcher scripts (`examples/*/bb`): pass arguments without
  quote-mangling — e.g. emit one escaped Scheme string per argument
  (escape backslash and double quote), or let `bb eval -` read the
  expression from stdin.
- Document the fixed invocation in AGENTS.md's tooling pitfalls section
  and remove the workaround wording once it lands.

## Proposals

1. Store-aware `bb eval` plus escaped-argument launchers — restores
   probing as the cheap verification path for agents.
2. Only fix the launcher quoting; keep eval base-library-only —
   smaller change, but committed-combiner probing stays impossible.
3. Keep the documented workaround — rejected: every new agent will
   pay the discovery cost again.
