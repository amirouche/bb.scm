Number: AWA0001
Title: Turtle playground — multi-agent webui example
Status: doing

## Abstract

Build a Logo-style turtle graphics playground: a small language
(`forward`, `backward`, `left`, `right`, `penup`, `pendown`, `color`,
`repeat N [ ... ]`) with a thin webui — textarea, Render button, inline
SVG — served by `bb serve`. The language core is a five-stage combiner
DAG (characters, tokens, command tree, run to segments, SVG), built
concurrently by several coding agents against check contracts committed
before any implementation exists.

## Context

`examples/multiagent` proved the multi-agent workflow on codecs
(roman numerals, duration parsing), but its DAG is shallow: mostly
independent leaves. A bigger exercise needs a deeper dependency graph
where agents compose through frozen interfaces rather than sit side by
side. Turtle graphics is the smallest complete language pipeline with
that property: tokenizer -> parser -> evaluator -> renderer, each stage
consuming the previous stage's committed output shape, plus a webui
layer on top — the bb thesis (logic hashed, presentation layered)
in miniature.

Platform facts the design relies on (verified in session):

- No `sin`/`cos` among the primitives; `xeno` reaches them
  (`(xeno "sin" 0)` -> 0, `(xeno "cos" 0)` -> 1, `floor` works).
- This Chez build lacks regexp, `string-split`, `string-downcase`;
  tokenizers are hand-rolled char work, the shape `md-inline` proved.
- Checks must not raise; unknown commands are values
  (`("error" "xyz")`), not exceptions, so error behavior is checkable.
- Float coordinates have epsilon noise (`cos 90` -> 6.1e-17); checks
  compare scaled-rounded coordinates
  (`(xeno "round" (* 1000 x))`), never raw equality.

## Description

Semantics contract (frozen before implementation):

- Turtle starts at (0, 0), heading 0 = north; x grows east, y grows
  north; `right` rotates clockwise; coordinates are floats.
- Moving with the pen down emits one segment
  `("segment" x1 y1 x2 y2 color)`; pen up emits nothing.
- `repeat N [ ... ]` nests arbitrarily.
- Program text -> tokens (`("word" "forward") ("number" 100) ("open")
  ("close")`), tokens -> command tree
  (`("forward" 100) ("repeat" 4 (...))`), tree -> segment list,
  segment list + bounds -> SVG string (renderer rounds to integer
  pixels; SVG y-flip is render-time only).

Combiner DAG (naming per AGENTS.md conventions):

```
Stage 0  characters   turtle-char-whitespace?  turtle-char-digit?
                          turtle-char-letter?
Stage 1  tokens       turtle-tokenize
Stage 2  parse        turtle-parse
Stage 3  run          turtle-state-step  turtle-run
Stage 4  geometry     turtle-bounds  turtle-segments->svg
Stage 5  webui        turtle-page (+ notes-style form-decode reuse)
```

Multi-agent plan:

- orchestrator writes the check contracts first (parse shape, square
  run, penup, bounds, SVG against a literally constructed segment list
  so the renderer does not depend on the runner), sanity-tests them in
  a scratch store, commits, assigns.
- agent-lexing (stage 0 + tokenize), agent-runner (state-step + run),
  agent-renderer (bounds + segments->svg) work concurrently in the same
  store, each with its own `BB_AUTHOR`, per-agent source filenames,
  `bb commit --mine` plus the worklog rule (author | task | done).
- optional race on `turtle-parse` (agent-racer) to re-exercise name
  racing one level up the DAG.
- integrator sweeps `bb check`, arbitrates any race on stated grounds,
  adds the webui, verifies with `bb serve` + curl, records findings.

Location: `examples/turtle/`. Preset programs (square, spiral
`repeat 36 [ forward 100 right 10 ]`, star
`repeat 5 [ forward 200 right 144 ]`) double as end-to-end acceptance;
the star is impossible with quarter-turn-only turtles, which is why
float coordinates were accepted.

## Proposals

1. **Proceed as described** — contracts first, three parallel agents,
   optional parse race, thin webui. Deep DAG, pure checks, matches the
   established process end to end.
2. **Drop the race, keep three agents** — simpler run; loses the
   mid-tree racing data point that `examples/multiagent` only has at
   leaf level.
3. **Quarter-turn-only turtle** (integer direction vectors, no trig) —
   exact integer checks, but no stars or spirals; weaker as a language
   exercise.
