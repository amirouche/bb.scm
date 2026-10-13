# multiagent — three agents, one store, zero coordination

A recorded run of the multi-agent workflow from AGENTS.md: three coding
agents worked concurrently in this same store directory — no branches,
no locks, no merge — against contracts committed before they started.

## The task

Two round-trippable codecs, chosen because their specs fit in one
paragraph and their contracts are pure test vectors:

- `roman-encode` / `roman-decode` — integers 1..3999 and roman numerals
- `duration-parse` / `duration-format` — `"1h30m"` and seconds

Plus a deliberate race: `duration-parse` was assigned to two agents at
once, same combiner name, to exercise convergence or arbitration.

## How it ran

```
orchestrator  writes 4 check contracts, sanity-tests them against a
              reference implementation and a mutant (PASS/FAIL), commits
├── agent-roman     BB_AUTHOR=agent-roman     roman-encode, roman-decode
├── agent-duration  BB_AUTHOR=agent-duration  duration-parse, duration-format
└── agent-racer     BB_AUTHOR=agent-racer     duration-parse (RACE)
                     all: add → add --check → check → commit --mine
orchestrator  adds round-trip checks, arbitrates the race, verifies
```

Every agent ran every `bb` command with its own `BB_AUTHOR` and promoted
only its own work with `bb commit --mine`. No agent ever used `--all`.

## Outcome

- **14 combiners committed by four distinct identities**, store valid
  (`bb validate`).
- The race produced **two different normalized trees** under one name:
  `duration-parse@943a66` (agent-duration) and `duration-parse@cdddc0`
  (agent-racer). Both survive; neither won by force.
- Both candidates **pass both checks** — the contract vectors and the
  round-trip through `duration-format`. `bb check <candidate>` prints
  2/2 for each; `bb run` gives identical results.
- With checks tied, the integrator picked `duration-parse@943a66` for
  downstream use, on two stated grounds: its helper
  (`duration-chars-scan`) follows the naming convention where the
  racer's (`duration-racer-scan`) carries a session artifact, and it is
  authored by the same agent as its round-trip partner. The loser is not
  deleted — it remains a first-class alternative with full lineage.
- Round-trip checks were added **at integration time**, once both codec
  directions existed — contracts layer: vectors first, composition
  later.

## Findings (now rules)

1. **The store handled the race exactly as designed.** Two adds of the
   same name with different trees: shadow note, qualified names, both
   committed by their own authors with `--mine`, no records lost.
2. **The flat files did not.** Both racers wrote `src/duration-parse.en.scm`
   — last writer wins at the filesystem; the store kept both identities.
   Flat files are disposable authoring surface. Racing the same combiner
   name requires per-agent source filenames (the racer's helpers used
   `duration-racer-*` for exactly this reason).
3. **A committed combiner whose helper stayed staged** (`agent-racer`'s
   first commit used an explicit ref and skipped its helper) was caught
   by `bb status` and fixed by steering the owning agent — the store
   makes incomplete promotion visible; it does not silently absorb it.
4. **Convergence is real but narrower than "same semantics."** The two
   implementations are behaviorally identical on every contract vector,
   yet their normalized trees differ — hash dedup catches isomorphic
   solutions only. Behavioral equivalence is the check suite's job, and
   here it tied 2/2, handing the decision to the integrator's tie-break.

## Explore the run

```sh
./bb status                    # who committed what
./bb check duration-parse@943a66
./bb check duration-parse@cdddc0
./bb run duration-format 93784
./bb show roman-encode         # definition + doc from the store
./bb tree roman-decode         # dependency DAG
cat combiners/*/lineage/*.committed.scm   # author attribution
```

## Program equivalence, certified

The two `duration-parse` trees are behaviorally identical but
structurally different — the hash cannot equate them (that is the Mobius
open question about program equivalence: can two different trees
computing the same values be decided equivalent?). In full generality
the answer is undecidable (Rice's theorem), but the architecture does
not need to *decide* equivalence to *carry* it: equivalence claims can
be content-addressed checks that anyone can re-run.

Here the domain is finite, so the certificate is exhaustive. Two
symmetric checks — `~check-duration-parse-agrees-chars` registered on
`duration-parse@cdddc0`, `~check-duration-parse-agrees-racer` registered
on `duration-parse@943a66` — verify that each tree computes the same
values as the other's implementation on every duration of 0..999
seconds, in both formatted and bare-number form. Both pass 3/3.

The spectrum the store already occupies:

| Layer | Question | Decidable | Mechanism |
|---|---|---|---|
| Alpha-equivalence | same tree modulo names? | yes, exact | the hash (convergence) |
| Bounded-domain equivalence | same values on a stated finite domain? | yes, by exhaustion | a check like the one above |
| Decidable-theory equivalence | same function over SMT theories? | yes, per fragment | Z3 (check returns a combiner) |
| Full extensional equivalence | same values everywhere? | no | carry certificates, don't decide |

The hash proves sameness of code; a check proves sameness of behavior
on a stated domain. Undecidability is not solved — it is externalized
into checkable, content-addressed certificates.
