# bb

**Harness the energy of the sun core, so that we become a crew, endlessly.**

> **Experimental**: This is research software under active development.

`bb` is short for *Beyond Babel*. It is the reference implementation of [Möbius](https://github.com/amirouche/mobius) — a content-addressed programming language and knowledge store, written in Chez Scheme.

## What it is

Every programmer who thinks in Wolof, Tamil, Vietnamese, or Tamazight and codes in English pays a cognitive tax. Every variable named in a second language is a thought translated before it's expressed. This overhead is invisible to the people who don't pay it — and universal for everyone who does.

bb makes that tax optional. It is three things:

- **A language** — Mobius (R⁰RM): 39 foundations plus one mechanism, `gamma`, the catamorphic pattern-matching combiner. Evaluation is tree-in, tree-out.
- **A store** — append-only and content-addressed. Every combiner is normalized to a de Bruijn tree and identified by its SHA-256 hash. Names, documentation, and language metadata are *mappings* stored alongside the hash — one per language.
- **A toolchain** — a git-like CLI for knowledge work: author, verify, navigate, evaluate, distribute.

Identity is the hash. The same algorithm written in Tamazight, Arabic, French, or English produces the identical SHA-256 — multilingualism is not a feature bolted on top; it is the architecture. Lineage is structural: derivation lives in hash pointers inside the content, not in a mutable registry someone controls. Priority is established by Bitcoin-anchored OpenTimestamps proofs — no institution, no permission.

## Three languages, one hash

A combiner that sums arbitrarily nested lists of integers, written three times, by three authors, none of them translating:

**English**

```scheme
(define total
  (gamma
    ((? integer? ,n) n)
    ((,(left) . ,(right)) (+ left right))
    (#nil 0)))
```

**Chinese (Mandarin)**

```scheme
(define 总和
  (gamma
    ((? integer? ,数) 数)
    ((,(左) . ,(右)) (+ 左 右))
    (#nil 0)))
```

**Tamazight (Tifinagh)**

```scheme
(define ⴰⵙⴽⴰⵔ
  (gamma
    ((? integer? ,ⴰⵎⴹⴰⵏ) ⴰⵎⴹⴰⵏ)
    ((,(ⴰⵣⴻⵍⵎⴰⴹ) . ,(ⴰⵢⴻⴼⴼⵓⵙ)) (+ ⴰⵣⴻⵍⵎⴰⴹ ⴰⵢⴻⴼⴼⵓⵙ))
    (#nil 0)))
```

Each `,(x)` is a catamorphic bind — it automatically applies the combiner to the matched sub-expression before the clause body runs. `(? integer? ,n)` is a predicate guard, `#nil` the base case. No explicit recursion. No traversal code. The gamma walks the tree by pattern alone.

```scheme
;; Three names, one hash — same logic, same identity.
(total 1 (list 2 (list 3 4)) 5)
;; => 15
```

Every version above normalizes to the same tree and hashes to `0320cb1c…` — the variable names are the only difference, and normalization erases them. Three clauses. Arbitrary depth. The recursion is in the commas.

Names are presentation; literals are logic. A combiner that matched on string tags — `("add" ,(a) ,(b))` versus `("加" ,(a) ,(b))` — would hash differently per language, because those strings are part of what the code *does*, not what it's called. Keep language out of the logic and identity crosses languages for free.

## What is possible today

v0.1.0 is useful at the scale of one person, without requiring a network:

- **Author** — `bb add` parses, normalizes, hashes, and stages a combiner; `bb commit` promotes it; `bb edit` round-trips through your editor; `bb refactor` propagates a hash substitution through a dependency tree.
- **Speak your language** — every combiner carries one mapping per language; retrieve, display, and search it under any of its names. `bb mapping` manages the views.
- **Verify** — `bb check` runs check suites: hard-coded assertions, and symbolic properties verified universally by Z3 when it is on `PATH` (degrading gracefully to skipped when it isn't). `bb review` records attestations; `bb validate` re-hashes the whole store.
- **Prove priority** — `bb anchor` requests and upgrades Bitcoin-anchored OpenTimestamps proofs.
- **Distribute** — `bb remote push/pull/sync` between stores, with selective `bb remote publish` of a ref and its closure.
- **Serve** — `bb serve` runs combiners behind an io_uring HTTP server without leaving the Mobius surface.

Three example projects ship under [`examples/`](examples/): a server-rendered click counter, TodoMVC, and a trilingual static-site generator — pure Mobius except for two I/O files — that produces [The Invariant](https://hyper.dev/mobius/the-invariant/en/), thirty stories in three languages, the user-facing combiners sharing one hash across their en/fr/es mappings. The system generates the fiction that describes the system.

## What comes next

The bottom half of [the manual](https://github.com/amirouche/mobius/blob/hello-weaver/manual.md) is the to-do list:

- **`bb prove` / `bb verify`** — Zero-Knowledge Proofs that a *sealed* combiner passes a public check suite, without disclosing the code. The check suite is the specification: content-addressed, forkable, translatable — and eventually the statement a proof attests to.
- **Atlas Stoa** — a read-only aggregation layer over federated stores: near-duplicate discovery, behavioral indexing by check suite, search along the language axis. A view, not an authority.
- **The formal corners** — a specified error model, effects as named patterns over continuations, `eval` as hash lookup, predicate inference. Fifteen open questions, honestly listed, not hand-waved.
- **Farther out: oblivious execution** — running a sealed combiner on private data (ORAM, TEEs, or MPC) so the executing machine observes neither the code nor the inputs.

The growth model is mycelium, not hockey stick: every store is viable standalone, and synchronization is optional.

## The stake

Defection looks rational inside a fog: opaque provenance, language asymmetry, gatekept access, attribution controlled by whoever owns the registry. Every existing software infrastructure was built inside that fog, and reproduces it. Make who-made-what and who-built-on-whom structurally visible, and cooperation stops requiring virtue — the equilibrium shifts because silent absorption stops being cheap.

The same structure collapses the cost of coordination among stakeholders. The hash is the meeting point: independent teams who solve the same problem find each other through identity, not committees. A check suite is a problem statement any party can verify against without trusting the author; a mapping lets each community keep its own names without a naming war; a refactor is a hash substitution, not a negotiation. Agreement is discovered, not brokered.

The last few years sharpened this: large language models absorbed the commons without preserving who made what. Content-addressing with timestamps rebuilds the lineage. The mirror doesn't prescribe norms or enforce justice. It refuses amnesia.

The cost of the status quo is not only unfairness to individuals. It is the civilizational cost of knowledge that never gets created — problems that stay unsolved because the people closest to them would have to think in a second language to work on them, while the credit lands elsewhere.

The yield is concrete. A kid in Tizi Ouzou publishes a combiner named in Tamazight, receives a Bitcoin-anchored proof, and is referenced by someone on another continent. No gatekeeper granted that. The hash is her institution. And it is the project's design law: if the system doesn't work for the Kid in Tizi Ouzou, it doesn't work.

This is the fifth iteration of the idea across 24 years, with no funding and no roadmap deck — the investment is *temps long*. The bet underneath is simple: knowledge should be a commons, not a commodity, and a commons needs infrastructure that refuses to forget.

## Getting started

Chez Scheme is the only dependency (`chezscheme` on Debian/Ubuntu; `chez-scheme` on Alpine, Arch, Fedora, and Void):

```bash
sudo apt install chezscheme

git clone https://github.com/amirouche/bb.scm
cd bb.scm
./bb repl
```

Or evaluate directly:

```bash
./bb eval '(+ 40 2)'
```

## Commands

```
Authoring      bb add · bb edit · bb commit · bb refactor
Verification   bb check · bb review · bb validate · bb diff
Navigation     bb show · bb search · bb tree · bb caller · bb resolve · bb log · bb status
Evaluation     bb eval · bb run · bb repl · bb print · bb serve
Distribution   bb remote add/push/pull/sync/publish · bb anchor
Housekeeping   bb store init/info · bb mapping · bb worklog
```

Run `./bb --help` for the full reference. Commands take a `<ref>` — `name@nid@lang@lid`, every trailing field optional — where the name can be in any language and the hash disambiguates.

## The Möbius constellation

- **[mobius](https://github.com/amirouche/mobius)** — the design: [the manual](https://github.com/amirouche/mobius/blob/hello-weaver/manual.md), the personas, the horizon
- **bb.scm** — this repository: the reference implementation, in Chez Scheme
- **[bb.py](https://github.com/amirouche/bb.py)** — the Python sibling where Beyond Babel started
- **Essays** — [Toward an Ecology of Memory and Computation](https://hyper.dev/2026/mobius-toward-an-ecology-of-memory-and-computation/) · [Product Brief](https://hyper.dev/2026/mobius-product-brief/) · [From Crisis to Commons](https://hyper.dev/2026/mobius-from-crisis-to-commons/) · [bb.scm v0.1.0](https://hyper.dev/2026/mobius-bb-scm/)
- **[The Invariant](https://hyper.dev/mobius/the-invariant/en/)** — thirty stories in three languages, generated by the system they are about

## Related work

- **[Unison](https://www.unison-lang.org/)** — content-addressable code where the hash is the identity
- **[Abstract Wikipedia](https://meta.wikimedia.org/wiki/Abstract_Wikipedia)** — multilingual knowledge that separates meaning from language
- **[Non-English-based programming languages](https://en.wikipedia.org/wiki/Non-English-based_programming_languages)** — the long history of the problem
- **Content-addressed storage** — Git, IPFS, Nix
- **[Situated software](https://en.wikipedia.org/wiki/Situational_application)** — local, contextual solutions

---

> "The only thing that makes life possible is permanent, intolerable uncertainty: not knowing what comes next."
>
> — Ursula K. Le Guin, *The Dispossessed*
