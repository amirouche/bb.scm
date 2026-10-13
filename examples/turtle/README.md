# turtle — five agents, one store, one picture

A Logo-style turtle graphics playground, built as a multi-agent bb
exercise one notch up from `examples/multiagent`: a five-stage
combiner DAG (characters -> tokens -> command tree -> segments ->
SVG) with contracts committed before any implementation existed,
four agents composing through those contracts in parallel, and a
deliberate mid-tree race on the parser.

Run it:

```
./bb serve turtle-state turtle-app --port 8101
# then open http://localhost:8101/
```

Presets: square, spiral (`repeat 36 [ forward 100 right 10 ]`),
star (`repeat 5 [ forward 200 right 144 ]` — impossible without
arbitrary-angle trig, which is why coordinates are floats and the
contracts compare scaled-rounded values).

## How it ran

```
orchestrator  writes CONTRACTS.md + 5 check contracts + 5 test helpers,
              sanity-tests every contract in a scratch store against a
              reference implementation (PASS) and a mutant (FAIL),
              commits, assigns
├── agent-lexing    BB_AUTHOR=agent-lexing    turtle-tokenize
├── agent-parser    BB_AUTHOR=agent-parser    turtle-parse
├── agent-racer2    BB_AUTHOR=agent-racer2    turtle-parse (RACE)
├── agent-runner    BB_AUTHOR=agent-runner    turtle-run
└── agent-renderer  BB_AUTHOR=agent-renderer  turtle-bounds,
                                               turtle-segments->svg
                   all: add -> add --check -> check -> commit --mine
                        -> worklog (author | task | done)
orchestrator  arbitrates the race, pulls the notes store as a remote
              (set-union reuse of form-get and md-escape), integrates
              turtle-draw + webui, verifies with serve + curl
```

The renderer worked against a literally-constructed segment fixture,
so it never depended on the runner existing — parallelism through
frozen data-shape contracts, not through coordination.

## Outcome

- The full closure passes: `bb check turtle-draw` prints 6/6
  (draw, segments->svg, run, tokenize, parse, bounds).
- The race produced two different normalized trees under one name:
  `turtle-parse@48020b` (agent-parser) and `turtle-parse@d7e714`
  (agent-racer2). Both pass `~check-turtle-parse` identically. The
  integrator re-asserted `@48020b` as primary on one stated ground:
  it was authored under the canonical filename (the racer's filename
  exists only because of the race protocol). `@d7e714` remains a
  first-class alternative with full lineage; nothing was deleted.
- Two broken intermediates were committed by their own agents
  (`turtle-run@697123`, `turtle-parse@0d4852`), marked superseded in
  their worklogs — immutability means mistakes stay on the record.
- Cross-store reuse: `bb remote add notes file://.../examples/notes`
  + `bb remote pull` brought in 29 committed combiners as a set union;
  the webui reuses `form-get` and `md-escape` without re-solving them.
- `bb validate`: store valid, 53 combiners.

## Findings

1. **Internal recursive defines work** (verified by probe before
   assignment): a combiner can keep its whole recursion inside one
   lambda body. This is the escape hatch from the DAG's no-mutual-
   recursion rule — both parse implementations (stack walks) and the
   repeat-expansion in `turtle-run` live in single combiners.
2. **Normalize does not catch structural mis-nesting.** A form
   closed in the wrong place normalized and staged cleanly, and only
   failed behaviorally at `bb check` (agent-runner's broken
   intermediate). Paren-balance checks are insufficient; check suites
   are the real gate.
3. **Same-name resolution after commit.** When a bad version and its
   fix are committed in one `--mine` batch they share a committed
   timestamp and the name can resolve to the bad one by hash order.
   Fix: re-add the good source, commit again, and re-verify with
   `bb check <name>`. Never leave a broken version staged next to its
   fix.
4. **The launcher wrapper double-quotes args naively**, so literal
   `"` inside `bb eval` expressions breaks the reader; `bb eval` also
   only installs the base library (committed combiners unbound).
   Agents verified language facts from committed sources instead of
   probing via eval.
5. **Substring asserts are weak.** An early svg mutant renamed
   `viewBox` to `notaviewBox` and still passed, because the latter
   contains the former as a substring. The orchestrator's sanity
   phase caught it and switched the mutant to a value mutation.
   Checks should pin values, not just substrings.
6. **SO_REUSEPORT silently load-balances.** Two bb `serve` instances
   bound the same port and curl requests landed on either; symptoms
   are intermittent wrong-app responses. Pick ports deliberately and
   check `ss -ltnp` before serving.
7. **`BB_AUTHOR` must be set from the very first command.** Records
   staged without it carry the empty config author, and
   `commit --mine` under a real identity will not match them.

## Layout

- `CONTRACTS.md` — the frozen interface between agents
- `src/` — authoring surface (one define per file, per-agent
  filenames for raced names)
- `combiners/`, `worklog/`, `reviewed/`, `config.scm` — the store
- `scratch/` — orchestrator-only sanity scaffolding (reference
  implementations and mutants), gitignored, never part of the DAG
