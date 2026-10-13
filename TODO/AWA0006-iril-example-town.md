Number: AWA0006
Title: iril.example — login-gated Möbius web shell for a family or town
Status: todo

## Abstract

Build a login-gated web shell, served by `bb serve`, where a small group
that knows itself (a family, a town) signs in to build its own tools
without writing code. Each member types a request in their own
language; a factory of agents turns it into Möbius combiners inside the
shell's store, each arriving with its parent hash, its author chain
(who asked, which agent wrote, who checked) and its checks described as
plain sentences the group can read and watch pass or fail. The shell
holds the group's data (a calendar's events, not just its code) as
content-addressed trees so that an edit is a derivation, renders
everything as server-side HTML readable on a phone, and surfaces
conflicts as decisions the group rules on, the way a town meeting
would. The login is the boundary that makes the group a group; the
store underneath is plain Möbius and can federate later or never.

## Context

`examples/multiagent` and `examples/turtle` proved the part of this that
is novel: several authors growing one checkable family of combiners in
one store, with no merge step, contracts committed before
implementations, identities carried by `BB_AUTHOR`, races kept as
`name@hashA` / `name@hashB` and arbitrated on stated grounds by `bb
check` plus a human ruling, and cross-store reuse by `bb remote pull` as
a set union (turtle pulled 29 combiners from `examples/notes`). The
rules distilled from those runs live in AGENTS.md ("Multi-agent
workflow").

Each clause of the vision maps onto something already exercised:

| Vision | Already in bb | Gap |
|---|---|---|
| factory of agents | orchestrator writes contracts, agents add / check / commit --mine (turtle) | triggered from a terminal by a human-driven session, not from a form |
| author chain | lineage carries `BB_AUTHOR`; worklog "author \| task \| done" entry; `bb review` attestation | "who asked" is recorded nowhere; worklog author is discipline (AWA0002) |
| checks as plain sentences | `bb add --check`, sanity rule (pass on reference, fail on mutant) | check docs are not rendered; no pass/fail view outside the CLI |
| own language per member | de Bruijn hash + per-language mappings | nothing; this is the thesis |
| data as content-addressed trees | append-only store, derivation chains for combiners | `serve` state is an in-memory box (`notes-state`); data trees untested |
| town-meeting conflicts | races survive with lineage; checks tie; integrator rules | no page listing ties and recording the ruling |
| login as boundary | `bb serve --api-key` (one bearer key, `server.scm:50`) | one key for everyone; no per-member identity, no `BB_AUTHOR` binding |
| phone rendering | server-rendered, no-JavaScript webuis (`notes`, `turtle`) | nothing |
| federate or stay alone | `bb remote add` / `pull` / `publish` | nothing |

Platform TODOs that bite harder inside a shell than in a terminal run:
AWA0002 (worklog author), AWA0004 (reader diagnostics an agent can act
on), AWA0005 (store-aware eval so agents can probe committed
combiners).

### Distance from the software-factory aspiration

The field (Factory 2.0, StrongDM, Cursor's swarm, Gas Town, Anthropic's
Managed Agents) is converging on a software factory in the industrial
sense: signals from the world (tickets, incidents, feedback, a spec)
turned into shipped, tested, deployed software with no human between
intent and artifact; thousands of agents in parallel in disposable
containers; output verified by tests, adversarial checkers and LLM
judges rather than human review; self-improvement by observing its own
runs; priced in tokens and session-hours against the salary it
replaces. The human writes the specification upstream and rules on
escalations downstream; the code becomes an opaque intermediate to be
regenerated rather than read; success is throughput of accepted changes
per dollar, not comprehension, attribution or anyone's ability to take
the result over later.

Where the current work already matches:

- Intent to artifact without a human writing code: the turtle and
  multiagent runs took a spec, produced contracts, and had agents add,
  check and commit combiners nobody read line by line. This task moves
  the signal source from a terminal prompt to a form.
- Verification by tests rather than review: checks are the interface;
  the sanity rule (pass on reference, fail on mutant) is an adversarial
  checker in miniature; races were arbitrated by `bb check`.
- Parallel agents with no merge step: five agents in one store, no
  branches, no locks, set-union integration.
- Rulings as escalations: the `duration-parse` and `turtle-parse` ties
  were surfaced and ruled on stated grounds.

Where it is far:

- Scale: five agents, 53 combiners, one run; nothing schedules,
  supervises or retries agents; the orchestrator was a human-driven
  session.
- No closed loop: no signal source (tickets, incidents), no deploy
  step, no feedback from running software into new tasks.
- No LLM judges: arbitration is exhaustive or bounded checks plus a
  human; the equivalence table in `examples/multiagent/README.md`
  stops at carrying certificates rather than deciding.
- No self-improvement: findings became AGENTS.md rules by hand; nothing
  reads the worklog to change the next run.
- No cost model: nothing measures tokens or session-hours per accepted
  change.
- Tooling friction that blocks unattended runs: AWA0002 (worklog
  author), AWA0004 (reader diagnostics), AWA0005 (store-aware eval).

Where it parts ways on purpose: the factory treats code as an opaque
intermediate and measures accepted changes per dollar; Möbius treats
the artifact as what must stay legible, attributed and takeoverable.
Every clause of this task that costs effort is on that side: the author
chain with who asked, checks rendered as sentences, data as
derivations, losers kept with lineage, federation as set union. A
factory would delete the losing `turtle-parse` tree; this store keeps
it and says who made it. The distance is one order of magnitude of
scale and one closed loop (unattended orchestrator, signal source,
deploy target), not a missing idea.

## Description

The shell is itself a combiner DAG built with the workflow it hosts:
frozen data shapes and check contracts first, then nodes assigned to
agents in parallel, in the `examples/turtle` layout
(`CONTRACTS.md`, `src/` one define per file, `scratch/` for
orchestrator sanity, store dirs).

### Data shapes (to freeze in CONTRACTS.md)

- Member: `("member" name language author-id)`. `author-id` is the
  value bound to `BB_AUTHOR` for everything this member causes.
- Request: `("request" id member-name language text status)`;
  `status` is one of `"open"`, `"assigned"`, `"checked"`, `"ruled"`.
- Task: `("task" request-id combiner-name depends-on-hashes
  check-sentences)` — the assignment an agent receives: "produce a
  combiner that passes these checks, depending only on these hashes".
- Check report: `("check" combiner-ref check-name sentence
  pass-or-fail)`.
- Author chain, per combiner: `("chain" asked-by written-by
  checked-by parent-hash)`. `asked-by` comes from the request's
  member; `written-by` from lineage (`BB_AUTHOR`); `checked-by` from
  `reviewed/`; `parent-hash` from the derivation chain.
- Decision: `("decision" name candidate-hashes chosen-hash grounds
  ruled-by)` — recorded as a `bb review` mark on the chosen hash plus
  a worklog entry carrying the grounds.
- Group data tree: a literal Möbius value stored as a combiner of no
  arguments (e.g. `calendar-events@hash`). An edit adds a new combiner
  with the previous hash as its parent in lineage; the shell always
  renders the latest derivation and keeps the chain browsable.

### Combiner DAG (names per AGENTS.md conventions)

```
Stage 0  identity    town-member-parse        login form -> member
                     town-member-author-id    member -> BB_AUTHOR value
Stage 1  requests    town-request-parse       form body -> request
                     town-request-list        state -> open requests
Stage 2  factory     town-task-plan           request -> task list
                     town-task-assign         task + agent -> assignment
Stage 3  gates       town-check-report        ref -> check reports
                     town-chain-build         ref -> author chain
                     town-conflict-list       state -> same-name ties
                     town-decision-record     decision -> review + worklog
Stage 4  data        town-tree-derive         tree + edit -> child tree
                     town-tree-latest         name -> newest derivation
Stage 5  pages       town-page-home, town-page-request,
                     town-page-checks, town-page-meeting,
                     town-page-tree            (reuse form-get, md-escape
                                               from examples/notes)
Stage 6  server      town-state, town          (state req) handler
```

Pages are built against literal fixtures (a hand-written request, a
hand-written author chain) so the renderer agent never waits on the
factory, as the turtle renderer never waited on the runner.

### Integration points in bb

- `server.scm`: replace the single bearer key with a member table so a
  login binds the session to a member and its `author-id`; the handler
  receives the member with the request. Every `bb add`, `commit`,
  `worklog`, `review` the shell performs on a member's behalf runs
  under that member's `BB_AUTHOR`.
- Agent invocation: the factory shells out to a coding agent (one
  `BB_AUTHOR` per agent, `commit --mine`, worklog rule) with the task
  record as its brief; the shell polls `bb status` and `bb check` for
  the result. No agent ever runs `commit --all`.
- Author chain: `asked-by` is written into the worklog message by the
  shell ("asked: <member> | author: <agent> | task: ... | done: ...")
  until AWA0002 gives the worklog a structured author field.
- Check sentences: the sentence is the check combiner's doc string;
  `town-check-report` reads it from the mapping and pairs it with the
  `bb check` outcome.
- Data trees need `bb add` to accept a literal value (or a zero-arity
  lambda returning one) and lineage to record the parent on re-add;
  verify in a scratch store before freezing the shape.

### Acceptance

- A member logs in, types "a shared calendar for the family" in
  French, and the factory commits a `calendar-*` family under the
  member's and the agent's identities; `bb status` shows both.
- The checks page lists each check's sentence with its pass/fail from
  `bb check`; a mutant committed by a test agent shows a failure.
- Two agents assigned the same combiner produce `name@hashA` /
  `name@hashB`; the meeting page lists the tie with both chains and
  check results; a ruling records a review mark and a worklog entry;
  the loser remains in the store.
- Editing an event produces a new `calendar-events@hash` whose lineage
  names the previous hash as parent; the old tree is still renderable.
- `bb validate` passes; `bb remote pull` from a second family store
  merges as a set union with no manual step.

## Proposals

1. **Build the shell as a bb example first, per-member login, data as
   zero-arity combiners** — `examples/iril/`, contracts first, agents
   in parallel, exactly the turtle process one notch up. Needs the
   `server.scm` member table and a data-tree probe; everything else is
   combiners. Recommended.
2. **Keep single `--api-key`, carry member identity in a form field** —
   no server change; identity is self-declared and unenforced, so the
   author chain is weaker. Acceptable as a spike to validate the pages
   and the factory loop before touching `server.scm`.
3. **Store group data outside the store (SQLite or files)** — simpler
   state, but edits become overwrites and the "edit is a derivation"
   clause is lost. Rejected: it gives up the property that makes the
   data theirs and checkable.
