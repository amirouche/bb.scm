Number: AWA0002
Title: Worklog entries must record their author
Status: todo

## Abstract

Extend worklog entries with an `author` field, populated from
`store-current-author` (honoring the `BB_AUTHOR` override) at write
time. Today an entry stores only combiner, message, and timestamp, so
per-agent attribution in the worklog is pure message-text discipline.

## Context

AGENTS.md requires each agent to write "author: <me> | task: ... |
done: ..." worklog entries after `bb commit --mine`, precisely because
`store-add-worklog-entry!` (src/bb/store.scm) does not record who wrote
the entry — unlike lineage records, which do carry the author. In the
turtle run, five agents' worklogs were only attributable because of the
message convention; a peer reading `worklog/` programmatically cannot
filter by agent. The same gap was noted when the worklog rule was
written: worklog entries "do not record BB_AUTHOR".

## Description

- `store-add-worklog-entry!`: add `(author . <name>)` to the entry
  alist, from `store-current-author` of the store root.
- `store-list-worklog-entries` and the `bb worklog` display: surface
  the author alongside timestamp and message.
- `~check-store-worklog` (src/bb/store.scm): extend to assert the
  author field is present.
- Keep the message-text convention for entries written before this
  change; the field is additive and old entries remain valid.
- Update the AGENTS.md worklog rule: identity in the message text
  becomes redundant once the platform stamps it.

## Proposals

1. Add the `author` field read from `store-current-author` at write
   time — one-line data model change, display and check updates.
2. Also stamp `BB_AUTHOR` into the automatic "committed <name>"
   entry written by `bb commit` — makes even agents that skip the
   manual entry attributable.
3. Leave it as message-text discipline — rejected: the platform can
   enforce what AGENTS.md currently has to ask for.
