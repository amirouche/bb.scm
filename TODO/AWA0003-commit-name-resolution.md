Number: AWA0003
Title: Same-name resolution after a batched commit can pick the superseded tree
Status: todo

## Abstract

When one `bb commit --mine` batch promotes several versions of the same
combiner name, they share a committed timestamp and the name then
resolves by hash order — which can select a superseded (e.g. broken)
tree. Give each promoted record in a batch a deterministic, ordered
commit marker and resolve names by it.

## Context

In the turtle run, agent-runner committed `turtle-run@697123` (a broken
intermediate) and `turtle-run@8fde4d` (its fix) in one `--mine` batch.
Both got identical committed timestamps; the WIP tie-break no longer
applied post-commit, and `turtle-run` resolved to the broken tree by
hash sort order. The agent had to re-add the good source and commit
again just to win the timestamp. The workaround is now a rule in
AGENTS.md ("never leave a broken version staged next to its fix"), but
the platform should not require that dance: iteration with same-name
re-adds is a normal workflow.

## Description

- In `command-commit` (src/bb/cli.scm), every promoted record in one
  batch currently shares one committed timestamp. Add a monotonically
  increasing per-record sequence (or microsecond-precision timestamps)
  so batch order is preserved.
- Name resolution (`store-build-name-index` / latest-committed lookup)
  must use that sequence as the tie-break, matching the WIP order the
  store already uses for staged records.
- Round-trip concern: `remote pull` is a set union of objects — the
  sequence must be part of the committed lineage record so a pulled
  store resolves the same way, without relying on wall-clock time.

## Proposals

1. Per-record commit sequence stored in the committed lineage record;
   resolution tie-breaks on it. Deterministic, federation-safe.
2. Higher-resolution timestamps (microseconds) — smaller change, but
   still racy across concurrent commits and clock skew across stores.
3. Keep the AGENTS.md workaround as the answer — rejected: it pushes a
   platform ordering concern into every agent's discipline.
