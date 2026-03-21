# bb

**Nurturing a society that recognizes diversity as strength through verifiable knowledge sharing.**

> **Experimental**: This is research software under active development.

Every programmer who thinks in Wolof, Tamil, Vietnamese, or Tamazight and codes in English pays a cognitive tax. Every variable named in a second language is a thought translated before it's expressed. This overhead is invisible to the people who don't pay it — and universal for everyone who does.

bb makes that tax optional. Write combiners in your language — name variables, write documentation, think natively. The tool separates what your code *does* from what you *called* things. Same logic, same hash, regardless of tongue.

Content-addressing gives every combiner a unique fingerprint. Authorship is preserved. Lineage is traceable. Knowledge is shared without losing track of who made what.

## The abacus: catamorphic arithmetic in six clauses

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

Each `,(a)` is a catamorphic bind — it automatically applies `arith-eval` to the matched sub-expression before the clause body runs. No explicit recursion. No traversal code. The gamma walks the tree by pattern alone.

```scheme
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

## Related Work

- **[Unison](https://www.unison-lang.org/)** — content-addressable code where the hash is the identity
- **[Abstract Wikipedia](https://meta.wikimedia.org/wiki/Abstract_Wikipedia)** — multilingual knowledge representation that separates meaning from language
- **[Situational application](https://en.wikipedia.org/wiki/Situational_application)** — local, contextual solutions (also known as Situated Software)
- **Non-English-based programming languages** — [Wikipedia overview](https://en.wikipedia.org/wiki/Non-English-based_programming_languages)
- **Content-addressed storage** — Git, IPFS, Nix
- **Multilingual programming** — Racket's #lang system, Babylonian programming
