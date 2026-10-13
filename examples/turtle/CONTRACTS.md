# turtle playground — frozen contracts

This file is the interface between agents. It is the contract; the
check combiners in `src/check-*.en.scm` are its executable form.
Orchestrator helpers in `src/` (tree-equal?, string-contains?,
turtle-round-tree, turtle-token-make, turtle-token-list) are shared
test infrastructure — do not re-implement them, they are already in
the store.

Read AGENTS.md at the repo root first: naming rules, multi-agent
rules, and the commit --mine + worklog discipline all apply.

## The language

```
forward 100      backward 50     left 45     right 90
penup            pendown         color red
repeat 4 [ forward 100 right 90 ]
```

Keywords are lowercase. `repeat N [ ... ]` nests arbitrarily.
Whitespace (space, newline, tab, carriage return) separates tokens.

## Semantics (frozen)

- Turtle starts at (0, 0), heading 0 = north, pen down, color black.
- x grows east, y grows north, `right` rotates clockwise (heading in
  degrees). Direction of a move: dx = sin(heading), dy = cos(heading).
- `forward n` / `backward n` move n units along / against the heading.
- Moving with the pen down emits one segment
  `("segment" x1 y1 x2 y2 color)`. Pen up emits nothing.
- `color` sets the color of segments emitted afterwards. A color is
  an opaque string ("red", "green", "blue", "black", ...).
- Coordinates are numbers; exact integer arithmetic stays exact
  (do not inject inexactness: no float constants on integer paths).
- Unknown words, and commands missing their argument, parse to
  ("error" word) — an error is a VALUE, never a raise. `turtle-run`
  skips error commands.

## Data shapes (frozen)

- Tokens: `("word" "forward")`, `("number" 100)`, `("open")`,
  `("close")`. Lists end with #nil.
- Command tree: `("forward" n)`, `("backward" n)`, `("left" n)`,
  `("right" n)`, `("penup")`, `("pendown")`, `("color" name)`,
  `("repeat" n (children...))`, `("error" word)`.
- Segment: `("segment" x1 y1 x2 y2 color)`.
- Bounds: `(min-x min-y max-x max-y)`; no segments -> `(0 0 0 0)`.

## Stage interfaces (what each agent must produce)

| Combiner | Signature | Owner |
|---|---|---|
| turtle-tokenize | text -> token list | agent-lexing |
| turtle-parse | token list -> command tree | agent-parser |
| turtle-run | command tree -> segment list | agent-runner |
| turtle-bounds | segment list -> bounds | agent-renderer |
| turtle-segments->svg | segment list -> SVG string | agent-renderer |

`turtle-segments->svg` must produce a document containing `<svg ...>`
... `</svg>`, a `viewBox="min-x min-y width height"` attribute
computed from the bounds (integer-valued bounds render as integers),
and each segment's color as its stroke.

Helper combiners are free — name them per the conventions, one
define per file, add them before their dependents.

## Mobius authoring facts (verified this session)

- Internal defines at the top of a lambda body work, including
  recursive ones. Use them; they keep one combiner self-contained.
- Mutual recursion ACROSS combiners is impossible (DAG). Repeat
  bodies are the trap: parse (nesting) and run (repeat expansion)
  both look like two mutually recursive functions. Solve them inside
  a single combiner (stack walk, accumulator threading), or with
  helper combiners added in dependency order.
- Only primitives, xeno, and previously added combiners resolve.
  Base-library names (not, list, append, reverse, length, cond, let,
  number?...) do NOT. Hand-roll or xeno them:
  (xeno "reverse" l), (xeno "length" l), (xeno "append" a b),
  (xeno "string=?" a b), (xeno "substring" s i j),
  (xeno "string-length" s), (xeno "string->number" s),
  (xeno "number->string" n), (xeno "round" n), (xeno "sin" n),
  (xeno "cos" n), (xeno "atan" n) — all verified.
- Degrees to radians: (* heading (xeno "atan" 1) (/ 1 45)).
- Booleans are #true / #false; empty list is #nil.
- Verify anything else with ./bb eval before betting a combiner on it.

## Per-agent workflow

1. Check what exists: ./bb search, ./bb tree, ./bb show <ref>.
2. Write your combiners in src/ under per-agent filenames when racing
   the same combiner name (see AGENTS.md).
3. Add in dependency order: ./bb add src/<name>.en.scm
4. Register the contract: ./bb add --check <your-ref> ~check-<name>
   (checks are already committed — associate, do not re-add unless
   asked).
5. ./bb check <your-ref> — must pass before you commit.
6. BB_AUTHOR=<you> ./bb commit --mine
7. ./bb worklog <your-ref> "author: <you> | task: <one sentence> |
   done: <what passed>"
8. Report your combiner refs (name@hash) back to the orchestrator.
