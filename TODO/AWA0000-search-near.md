Number: AWA0000
Title: search-near — structural nearness over de Bruijn trees
Status: todo

## Abstract

Compute a well-defined distance between stored combiners over their
normalized (de Bruijn) trees, and use it for near-duplicate detection at
`bb add` time, ranked refactor candidates, and mapping inheritance.
Nearness proposes relations (fork/fix/refine); checks verify behavior.
Nearness never decides anything on its own.

## Context

- Normalization erases names, so structural distance is not polluted by
  naming conventions: two refactorings of the same idea in the same
  shape land on the same canonical tree. Nearness between stored
  combiners is therefore measurable, not vibes.
- Small combiners are a platform design law, which keeps trees small
  enough for exact tree-edit-distance on shortlists and cheap
  indexing.
- The `examples/multiagent` race demonstrated the need concretely:
  `duration-parse@943a66` and `duration-parse@cdddc0` are
  behaviorally identical on an exhausted domain (certified by
  ~check-duration-parse-agrees-*) but structurally different — the
  hash cannot equate them, and nothing in the store surfaces their
  nearness to an author at add time.
- The general case of program equivalence is undecidable (Rice), so
  nearness must stay a ranking signal, never a verdict. The `IV`/`IIII`
  mutant in the contract sanity run is the canonical warning: one
  literal of distance, opposite behavior.
- `TODO.md` already lists `bb search --near` (SimHash or
  tree-edit-distance); this task formalizes it.

## Description

- Define the nearness metric over normalized trees: exact tree edit
  distance as the reference; cheaper prefilters for candidate
  selection (size delta, primitive multiset, top-level shape).
- Index the store for candidate bucketing (every `bb add` should be
  able to ask "what is near this tree?" without scanning linearly in a
  large store).
- Integrate:
  - `bb search --near <ref>` — list stored combiners by distance.
  - `bb add` warning: "near match found (distance N, hash X) — consider
    `--relation=refine <ref>` instead of a fresh add."
  - `bb refactor` — rank dependents and near candidates before hash
    substitution.
  - mapping inheritance: a tree near an existing one may inherit its
    mapping with a delta, so small structural changes become small
    translation changes per language.
- Emit lineage suggestions, never automatic relations: the human or
  agent confirms the relation; checks confirm the behavior.

## Proposals

1. **Shared-subtree hashing (start here).** The tree is content; hash
   its subtrees and compare subtree-hash sets (Jaccard). Cheap,
   incremental, and principled in a content-addressed store; gives a
   similarity score in [0,1] before any edit-distance machinery.
2. **Canonical serialization + SimHash bucketing.** Serialize the
   normalized tree deterministically, SimHash for coarse bucketing,
   exact tree-edit-distance on the shortlist for the reported number.
3. **Prefilter stack.** Size delta and primitive-multiset first;
   subtree-hash Jaccard second; edit distance last. The first two are
   indexable, the last is the ground truth.
4. **Semantic guardrail.** Every nearness report should be accompanied
   by the existing checks of the candidates ("near, and here is what
   its checks say") so the reader sees structure and behavior together.
