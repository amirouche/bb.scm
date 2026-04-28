# bb

**Harness the energy of the sun core, so that we become a crew, endlessly.**

> **Experimental**: This is research software under active development.

Every programmer who thinks in Wolof, Tamil, Vietnamese, or Tamazight and codes in English pays a cognitive tax. Every variable named in a second language is a thought translated before it's expressed. This overhead is invisible to the people who don't pay it — and universal for everyone who does.

bb makes that tax optional. Write combiners in your language — name variables, write documentation, think natively. The tool separates what your code *does* from what you *called* things. Same logic, same hash, regardless of tongue.

Content-addressing gives every combiner a unique fingerprint. Authorship is preserved. Lineage is traceable. Knowledge is shared without losing track of who made what.

## The abacus: catamorphic arithmetic in six clauses

**English**

```scheme
(define arith-eval
  (gamma
    (("num" ,n) n)
    (("add" ,(a) ,(b)) (+ a b))
    (("sub" ,(a) ,(b)) (- a b))
    (("mul" ,(a) ,(b)) (* a b))
    (("neg" ,(a)) (- 0 a))
    (("do" ,(result)) result)))
```

**Chinese (Mandarin)**

```scheme
(define 求值
  (gamma
    (("数" ,n) n)
    (("加" ,(a) ,(b)) (+ a b))
    (("减" ,(a) ,(b)) (- a b))
    (("乘" ,(a) ,(b)) (* a b))
    (("负" ,(a)) (- 0 a))
    (("算" ,(result)) result)))
```

**Tamazight (Tifinagh)**

```scheme
(define ⴰⵙⴽⴰⵔ
  (gamma
    (("ⴰⵎⴹⴰⵏ" ,n) n)
    (("ⵔⵏⵓ" ,(a) ,(b)) (+ a b))
    (("ⴽⴽⴻⵙ" ,(a) ,(b)) (- a b))
    (("ⵔⴱⵓ" ,(a) ,(b)) (* a b))
    (("ⴰⵢⵏⴰⴳⴻⵏ" ,(a)) (- 0 a))
    (("ⴻⵔⵔ" ,(result)) result)))
```

Each `,(a)` is a catamorphic bind — it automatically applies the combiner to the matched sub-expression before the clause body runs. No explicit recursion. No traversal code. The gamma walks the tree by pattern alone.

```scheme
;; Three names, one hash — same logic, same identity.
(arith-eval "do"
  (make-sub (make-mul (make-num 10) (make-num 3))
            (make-add (make-num 5) (make-num 7))))
;; => 18
```

Six clauses. Arbitrary depth. The recursion is in the commas.

## What it enables

bb is a tool for sharing content-addressed knowledge that is verifiable, maintainable, and preserves authorship and lineage.

- **Think in your language** — variable names and documentation in your native tongue, without penalty
- **Share across languages** — retrieve any combiner in any language
- **Verify identity** — same logic always produces the same hash, no matter who wrote it or in what language
- **Preserve lineage** — every combiner is traceable; who made what, who built on whom
- **Compose and build** — combiners reference other combiners; dependencies are tracked by hash
- **Catamorphic recursion** — `,(x)` patterns auto-recurse, replacing explicit traversal with declarative structure
- **De Bruijn normalization** — variable names erased to positional indices, making identity independent of naming

## How it works

```
Source → Parse → Normalize (de Bruijn) → Hash → Store
```

Normalization erases all variable names to positional de Bruijn indices — index 0 is always the enclosing combiner (self-reference), and each binding shifts the index. The result: any combiner with the same logical structure produces the same SHA-256 hash, regardless of the names chosen by the author.

The original names, documentation, and language metadata are stored alongside the hash — one mapping per language. This separates identity (the logic) from presentation (the language).

Exact matching is the foundation — the clean case where two people write the same logic independently and the hash proves it. For the realistic case where two people solve the same problem differently, semantic search surfaces near-matches: similar structure, different choices. Convergence isn't forced. It's discovered. The hash is the meeting point — independent teams who solve the same problem find each other through identity, not coordination.

## Vision

bb *is* the Möbius seed — a content-addressed language where timestamps make lineage visible, and names are views into a multilingual registry. Who made what, who built on whom, who absorbed whose work without credit. The mirror doesn't prescribe norms or enforce justice. It refuses amnesia.

## Getting Started

### Install Chez Scheme

**Alpine**
```bash
sudo apk add chez-scheme
```

**Arch Linux**
```bash
sudo pacman -S chez-scheme
```

**Debian / Ubuntu**
```bash
sudo apt install chezscheme
```

**Fedora**
```bash
sudo dnf install chez-scheme
```

**Void Linux**
```bash
sudo xbps-install chez-scheme
```

### Clone and run

```bash
git clone https://github.com/amirouche/bb.scm
cd bb.scm/north
./bb repl
```

## Command reference

```
bb — Mobius Seed evaluator and store manager

Usage:
  bb add [--derived-from=<ref>] [--relation=<type>] <file|->
                                            Parse, normalize, store, and bind
  bb add --check <combiner> <check>         Register check for combiner
  bb caller <ref>                         Show reverse dependency DAG
  bb check <ref>                          Run all checks for ref and its dependencies
  bb commit [name... | --all]             Promote staged combiners to committed
  bb diff <ref> <ref>                     Compare two combiners (pretty-printed diff)
  bb edit <ref> [lang]                    Edit combiner in $EDITOR, re-add on save
  bb eval <expression>                    Evaluate a single expression
  bb log [ref]                            Show timeline
  bb print <ref>                          Output Chez Scheme library with all dependencies
  bb anchor <ref>                         Request or upgrade OpenTimestamps proof
  bb refactor <ref> <ref> <ref> [<ref>]   Replace old with new in root tree
  bb mapping list <ref>                   List all mappings for a combiner
  bb mapping delete <ref>                 Delete a mapping (ref must include mapping hash)
  bb mapping set <ref> <key> <value>      Set a mapping entry (0=name, 1+=params)
  bb remote add <name> <path>             Add a remote store endpoint
  bb remote list                          List configured remote store endpoints
  bb remote remove <name>                 Remove a remote store endpoint
  bb remote push <name>                   Push committed combiners to remote
  bb remote pull <name>                   Pull committed combiners from remote
  bb remote sync                          Pull and push all configured remotes
  bb remote publish <name> <ref>          Mark ref (and closure) public to <name>
  bb remote stop <name> <ref>             Stop publishing ref to <name>
  bb repl                                 Interactive Seed session
  bb resolve <ref>                        Resolve ref to full spec
  bb review <ref>                         Mark combiner as reviewed
  bb run <ref> [args...]                  Evaluate a registered combiner
  bb search <query>                       Search combiner names and content
  bb show <ref>                           Display combiner doc and definition
  bb status                               Show working state
  bb store info                           Show store statistics
  bb store init                           Create a new mobius-store
  bb tree <ref>                           Show dependency DAG
  bb validate                             Verify store integrity
  bb worklog <ref> [msg]                  View or add work log entries
  bb --help                               Show this help
  bb --version                            Show version
```

## Related Work

- **[Unison](https://www.unison-lang.org/)** — content-addressable code where the hash is the identity
- **[Abstract Wikipedia](https://meta.wikimedia.org/wiki/Abstract_Wikipedia)** — multilingual knowledge representation that separates meaning from language
- **[Situational application](https://en.wikipedia.org/wiki/Situational_application)** — local, contextual solutions (also known as Situated Software)
- **Non-English-based programming languages** — [Wikipedia overview](https://en.wikipedia.org/wiki/Non-English-based_programming_languages)
- **Content-addressed storage** — Git, IPFS, Nix
- **Multilingual programming** — Racket's #lang system, Babylonian programming

---

> "The only thing that makes life possible is permanent, intolerable uncertainty: not knowing what comes next."
>
> — Ursula K. Le Guin, *The Dispossessed*
