# bb CLI Testing Plan

## Overview

This plan covers systematic testing of every exported and internal function in `bb/cli.scm`, including command dispatch, all commands, helper functions, error handling, and integration scenarios.

**Source**: `bb/bb/cli.scm` (2857 lines)
**Exports**: `main`, `~check-cli-build-argument-tree`, `~check-cli-mobius-write-surface`, `~check-cli-replace-ref`, `~check-cli-diff-trees`, `~check-cli-prepare-for-pretty`, `~check-cli-post-process`, `~check-cli-lcs-lines`, `~check-cli-resolve-ref`, `~check-cli-show`, `~check-cli-print`

---

## 1. Command Dispatch & Argument Parsing

### 1.1 `main` (line 2370)
The main entry point. Dispatches on `(car arguments)` via a `cond` chain.

- [ ] `bb` (no args) → calls `print-usage`
- [ ] `bb --help` → calls `print-usage`
- [ ] `bb --version` → prints `"bb 0.2.0"`
- [ ] `bb eval <expr>` → routes to `command-eval`
- [ ] `bb repl` → routes to `command-repl`
- [ ] `bb add <file> [<lang>]` → routes to `command-add`
- [ ] `bb commit <names...>` → routes to `command-commit`
- [ ] `bb edit <name>` → routes to `command-edit`
- [ ] `bb diff <a> <b>` → routes to `command-diff`
- [ ] `bb refactor <old> <new>` → routes to `command-refactor`
- [ ] `bb resolve <ref>` → routes to `command-resolve`
- [ ] `bb review <name>` → routes to `command-review`
- [ ] `bb search <query>` → routes to `command-search`
- [ ] `bb worklog <name> [msg]` → routes to `command-worklog`
- [ ] `bb validate` → routes to `command-validate`
- [ ] `bb anchor <remote>` → routes to `command-anchor`
- [ ] `bb remote <sub>` → routes to `command-remote`
- [ ] `bb run <name>` → routes to `command-run`
- [ ] `bb status` → routes to `command-status`
- [ ] `bb show <name>` → routes to `command-show`
- [ ] `bb print <name>` → routes to `command-print`
- [ ] `bb tree <name>` → routes to `command-tree`
- [ ] `bb caller <name>` → routes to `command-caller`
- [ ] `bb log [name]` → routes to `command-log`
- [ ] `bb store init` → routes to `command-store-init`
- [ ] `bb store info` → routes to `command-store-info`
- [ ] `bb store` (no subcommand) → prints "missing subcommand" message
- [ ] `bb store badcmd` → prints "unknown subcommand"
- [ ] `bb unknown-command` → prints error, exit 1
- [ ] Command names are case-sensitive (`bb RUN` → unknown)
- [ ] `main` can be called with explicit args (bypasses `command-line`)

### 1.2 `print-usage` (line 56)
- [ ] Prints all command descriptions
- [ ] Prints version number at end
- [ ] All commands listed match actual dispatch table

### 1.3 `bb-version` (line 54)
- [ ] Value is `"0.2.0"`

---

## 2. Value Display — `mobius-display-value` (line 111)

Prints Mobius values in readable format. Used by `command-eval` and `command-run`.

- [ ] `#nil` → displays `"#nil"` (mobius-nil)
- [ ] `#void` → displays `"#void"` (mobius-void)
- [ ] `#eof` → displays `"#eof"` (mobius-eof)
- [ ] `#true` / `#false` → displays boolean
- [ ] `"hello"` → displays with quotes (via `write`)
- [ ] `#\a` → displays `"#\a"` (character)
- [ ] `42` → displays `"42"` (integer)
- [ ] `3.14` → displays `"3.14"` (flonum)
- [ ] `(1 2 3)` → displays `"(1 2 3)"` (proper list terminated by nil)
- [ ] `(1 . 2)` → displays `"(1 . 2)"` (dotted pair)
- [ ] `(1 2 . 3)` → displays `"(1 2 . 3)"` (improper list)
- [ ] Named combiner → displays `"#<combiner name>"`
- [ ] Unnamed combiner → displays `"#<combiner>"`
- [ ] Nested structures → recursion works correctly

**Suggested `~check-*`:** `~check-cli-mobius-display-value`

---

## 3. Surface Writer — `mobius-write-surface` (line 146)

Writes denormalized surface expressions. Used by `command-edit`.

- [ ] `#nil` → `"#nil"`
- [ ] `#void` → `"#void"`
- [ ] `#eof` → `"#eof"`
- [ ] `#true` / `#false` → boolean display
- [ ] String → quoted via `write`
- [ ] Character → `"#\c"` format
- [ ] Integer → number display
- [ ] Flonum → number display
- [ ] Symbol → symbol name string
- [ ] `(mobius-unquote x)` → `",x"` (pattern bind)
- [ ] `(mobius-unquote _)` → `",_"` (wildcard)
- [ ] `(mobius-unquote-recurse tail)` → `",(tail)"` (catamorphic bind)
- [ ] Proper list `(a b c)` → `"(a b c)"` (nil-terminated)
- [ ] Dotted pair `(a . b)` → `"(a . b)"`
- [ ] Nested list with patterns → correct output
- [ ] Empty list `()` → `"()"` (null-terminated)

**Existing test:** `~check-cli-mobius-write-surface` — covers integer, `,x`, `,(x)`, `,_`, and list with patterns.

---

## 4. String Helpers

### 4.1 `string-trim` (line 229)
- [ ] Leading whitespace removed: `"  hello"` → `"hello"`
- [ ] Trailing whitespace removed: `"hello  "` → `"hello"`
- [ ] Both: `"  hello  "` → `"hello"`
- [ ] No whitespace: `"hello"` → `"hello"`
- [ ] All whitespace: `"   "` → `""`
- [ ] Empty string: `""` → `""`
- [ ] Tabs and mixed whitespace: `"\t hello \n"` → `"hello"`

### 4.2 `read-line` (line 244)
- [ ] Reads characters until newline
- [ ] Returns string without the newline
- [ ] EOF with no characters → returns eof-object
- [ ] EOF with accumulated characters → returns the string
- [ ] Empty line (just newline) → returns `""`

### 4.3 `string-contains?` (line 256)
- [ ] Substring present → `#t`
- [ ] Substring absent → `#f`
- [ ] Needle at start → `#t`
- [ ] Needle at end → `#t`
- [ ] Needle equals haystack → `#t`
- [ ] Needle longer than haystack → `#f`
- [ ] Empty needle → `#t` (matches at position 0)
- [ ] Empty haystack, non-empty needle → `#f`

### 4.4 `string-split-at-sign` (line 281)
- [ ] `"name@lang"` → `("name" "lang")`
- [ ] `"name"` (no @) → `("name")`
- [ ] `"name@hash@lang"` → `("name" "hash" "lang")`
- [ ] Empty string → `("")`

### 4.5 `string-replace` (line 1492)
- [ ] Replaces all occurrences of target with replacement
- [ ] No match → returns original string
- [ ] Multiple matches → all replaced

### 4.6 `string-split-lines` (line 1514)
- [ ] Splits on newlines
- [ ] Single line → list of one
- [ ] Empty string → appropriate handling

### 4.7 `string-trim-whitespace` (line 1117)
- [ ] Trims leading and trailing whitespace

**Suggested `~check-*`:** `~check-cli-string-helpers`

---

## 5. Reference Resolution & Name Index

### 5.1 `resolve-ref` (line 341)
Multi-part reference resolution supporting `name`, `name@lang`, `hash@lang`, `name@hash@lang`, etc.

- [ ] 1-part ref — exact name match
- [ ] 1-part ref — full hash match
- [ ] 1-part ref — unique prefix match
- [ ] 1-part ref — ambiguous hash prefix raises error
- [ ] Ambiguous name auto-picks most recent by timestamp
- [ ] 1-part ref — no match raises error
- [ ] 2-part ref — `name@lang`
- [ ] 2-part ref — `hash@lang`
- [ ] 2-part ref — `hash@mappingHash` (non-alphabetic)
- [ ] 3-part ref — `name@combinerHash@lang`
- [ ] 3-part ref — `name@lang@mappingHash`
- [ ] 4-part ref — `name@combinerHash@lang@mappingHash`

**Existing test:** `~check-cli-resolve-ref` — covers all 12 resolution cases plus `looks-like-lang?` heuristic.

### 5.2 `looks-like-lang?` (line 295)
- [ ] Short alphabetic strings → `#t` (e.g., `"en"`, `"fr"`)
- [ ] Hex-looking strings → `#f`
- [ ] Long strings → `#f`

### 5.3 `resolve-hash-only` (line 266)
- [ ] Exact hash match → returns hash
- [ ] Unique prefix match → returns full hash
- [ ] Ambiguous prefix → error

### 5.4 `resolve-name-to-hash` (line 304)
- [ ] Name in index → returns hash
- [ ] Missing name → returns `#f`

### 5.5 `make-name-lookup` (line 444)
- [ ] Creates name→hash lookup function from name index
- [ ] Known name → returns hash
- [ ] Unknown name → returns `#f`

### 5.6 `make-hash->name` (line 542)
Builds a reverse lookup: hash → symbol name from the store-derived name index.

- [ ] Known hash → returns symbol
- [ ] Unknown hash → returns `#f`
- [ ] Multiple entries → returns first match
- [ ] Empty name index → always returns `#f`

### 5.7 `shortest-unique-prefix` (line 710)
- [ ] Finds minimal unique hash prefix (>= 6 chars)
- [ ] Single hash → returns 6-char prefix
- [ ] Shared prefix → returns longer prefix to disambiguate

### 5.8 `load-combiner-value` (line 560)
Loads a single combiner from store, denormalizes, and evaluates.

- [ ] Loads body from `load-combiner`
- [ ] Loads mapping from `load-first-mapping`
- [ ] Calls `denormalize-tree` with body, mapping, and hash->name
- [ ] Returns evaluated result via `mobius-eval`
- [ ] Missing combiner → propagates error from store layer

### 5.9 `load-index-into-env` (line 569)
Loads all name-index entries into an evaluation environment.

- [ ] Pre-binds all names to `#void` (for mutual references)
- [ ] Loads each combiner value and updates binding
- [ ] Assigns combiner name for self-reference (unnamed combiners get named)
- [ ] Already-named combiners keep their existing name
- [ ] Empty name index → returns env unchanged
- [ ] Multiple entries → all loaded and bound

### 5.10 `extract-refs` (line 697)
Extracts all `(mobius-constant-ref hash)` references from a tree.

- [ ] `(mobius-constant-ref "abc")` → `("abc")`
- [ ] Nested refs → all collected
- [ ] No refs → `()`
- [ ] Non-pair atom → `()`
- [ ] Duplicate refs → all returned (not deduplicated)

### 5.11 `extract-named-refs` (line 1780)
Extracts named references (hash→name pairs) from a tree.

- [ ] Returns list of `(name . hash)` pairs
- [ ] Unknown hashes → uses hash as name

**Suggested `~check-*`:** `~check-cli-extract-refs`

---

## 6. Commands — Core

### 6.1 `command-eval` (line 97)
- [ ] `bb eval '(+ 2 3)'` → `5`
- [ ] `bb eval '(define x 42)'` → evaluates, displays last value
- [ ] `bb eval` (no args) → error to stderr, exit 1
- [ ] Multiple expressions in string → evaluates all, displays last
- [ ] Reader syntax error → error
- [ ] Undefined name → error
- [ ] Installs base library (arithmetic, list ops, etc.)

### 6.2 `command-repl` (line 190)
- [ ] Prints banner with version
- [ ] Prompts with `"bb> "`
- [ ] Evaluates expressions and displays results
- [ ] `#void` results not printed (e.g., `define`)
- [ ] Empty line → re-prompts (no error)
- [ ] Ctrl-D (EOF) → prints `"Goodbye."` and exits
- [ ] Errors caught by `guard` → printed to stderr, loop continues
- [ ] Environment persists across lines (`define` then reference)
- [ ] Uses `string-trim` on input
- [ ] Uses `read-line` for input

### 6.3 `command-add` (line ~1168 via `edit-store-all!`)
- [ ] `bb add file.scm [lang]` → parse, normalize, hash, store, register
- [ ] `bb add - [lang]` → reads from stdin
- [ ] Prints `"staged: name -> hash..."` for each define
- [ ] Prints `"Done. Use 'bb commit' to finalize."`
- [ ] Missing args → error to stderr, exit 1
- [ ] Loads existing name index into env (mutual refs work)
- [ ] Creates WIP lineage via `record-wip-lineage!`
- [ ] Invalid syntax → reader error
- [ ] Missing file → file-not-found error
- [ ] Multiple defines in one file → each stored separately
- [ ] Non-define top-level forms → evaluated but not stored
- [ ] Duplicate name → overwrites mapping
- [ ] `~check-` prefix stripped from self-name in mapping position 0
- [ ] `--derived-from` and `--relation` flags supported
- [ ] Check combiners stored with check hashes in lineage

### 6.4 `command-run` (line 1021)
- [ ] `bb run name` → loads and displays combiner value
- [ ] `bb run name arg1 arg2` → evaluates args, builds argument tree, applies
- [ ] Missing args → error to stderr, exit 1
- [ ] Name resolved via name index, falls back to raw hash
- [ ] Loads full name index into env
- [ ] Argument strings parsed as Mobius expressions
- [ ] Uses `build-argument-tree` for argument construction
- [ ] Non-existent name/hash → error from store layer

---

## 7. Commands — Store Management

### 7.1 `command-store-init` (line 603)
- [ ] Creates subdirectories: `combiners/`, `constants/`, `reviewed/`, `worklog/`
- [ ] Creates `config.scm` with default author template
- [ ] Creates `.gitignore` with bb-specific patterns
- [ ] Creates store directory structure
- [ ] Default directory is `(current-directory)`
- [ ] Optional argument overrides directory
- [ ] Idempotent: existing files/dirs not overwritten (`unless file-exists?`)
- [ ] Prints `"Initialized mobius store at <dir>"`

### 7.2 `command-store-info` (line 642)
- [ ] Prints store root path
- [ ] Prints combiner count
- [ ] Lists each entry as `"name -> hash..."`
- [ ] Empty store → shows 0
- [ ] Requires `find-store-root` (error if no store)

### 7.3 `command-status` (line 666)
- [ ] Empty store → `"Empty store. Use 'bb add' to register combiners."`
- [ ] Non-empty → prints count and per-combiner state
- [ ] States displayed: `[wip]`, `[committed]`, `[committed, reviewed]`, `[unknown]`
- [ ] Checks `has-committed-lineage?`, `list-wip-files`, `is-reviewed?` per entry
- [ ] `[unknown]` when neither committed nor wip (edge case)

---

## 8. Commands — Dependency Graph

### 8.1 `command-tree` (line 857)
- [ ] Shows dependency DAG downward
- [ ] Indentation via `(* depth 2)` spaces
- [ ] Shows display name and abbreviated hash `[hash...]`
- [ ] Uses visited hashtable to prevent infinite loops
- [ ] Deduplicates deps per combiner (via `seen` hashtable)
- [ ] Name resolved from name index, falls back to hash substring
- [ ] Missing args → error to stderr, exit 1
- [ ] Recursive: follows `mobius-constant-ref` deps

### 8.2 `command-caller` (line 900)
- [ ] Shows reverse dependency DAG (who references target?)
- [ ] Prints header `"Callers of <name>:"`
- [ ] Scans all name-index entries, extracts refs from each body
- [ ] Uses `member` to check if target-hash is in deps
- [ ] No callers → just header, no entries
- [ ] Missing args → error to stderr, exit 1
- [ ] Name resolved via name index, falls back to raw hash

---

## 9. Commands — Lineage & Log

### 9.1 `list-lineage-files` (line 933)
- [ ] Lists `.scm` files in combiner's `lineage/` subdirectory
- [ ] Returns empty list if lineage dir doesn't exist
- [ ] Filters by `.scm` suffix

### 9.2 `load-lineage-record` (line 943)
- [ ] Reads and returns S-expression from lineage file
- [ ] Correct path construction: `combiners/HASH/lineage/filename`

### 9.3 `command-log` (line 949)
- [ ] No args → shows timeline for all combiners
- [ ] With name arg → shows timeline for specific combiner
- [ ] Collects lineage records from all entries (or specific one)
- [ ] Sorts by timestamp: prefers `committed` date, falls back to `created`
- [ ] Handles missing timestamps (sort returns `#f`)
- [ ] Displays: timestamp, relation, `[wip]` flag, name, author
- [ ] `[wip]` shown when no `committed` field in record
- [ ] Empty records → `"No lineage records found."`
- [ ] Author shown only when non-empty string

---

## 10. Commands — Display & Output

### 10.1 `command-show` (line 845)
- [ ] Displays combiner with doc comments and pretty-printed definition
- [ ] Uses `show-combiner-with-mapping` for output
- [ ] Missing args → error to stderr, exit 1

### 10.2 `show-combiner-with-mapping` (line 826)
- [ ] Denormalizes tree with body, mapping, hash->name
- [ ] Displays doc comments prefixed with `;;`
- [ ] Pretty-prints `(define name ...)` form

### 10.3 `command-print` (line 722)
- [ ] Outputs full Chez Scheme library form with dependencies
- [ ] Resolves dependency graph and includes all referenced combiners
- [ ] Uses `shortest-unique-prefix` for hash disambiguation
- [ ] Handles duplicate names via mapping

**Existing tests:** `~check-cli-show`, `~check-cli-print`

---

## 11. Commands — Edit Workflow

### 11.1 `command-edit` (line 1346)
- [ ] Opens combiner in `$EDITOR` for editing
- [ ] Denormalizes tree via `denormalize-tree` with body, mapping, hash->name
- [ ] Includes check combiners in edit buffer
- [ ] `~check-` prefix prepended when reading stripped mapping name
- [ ] Re-adds on save via `edit-save-flow`
- [ ] Missing args → error to stderr, exit 1
- [ ] Name resolved via name index, falls back to raw hash

### 11.2 `classify-defines` (line 1136)
- [ ] Separates defines into main and `~check-*` categories
- [ ] Non-define forms classified separately

### 11.3 `edit-run-checks` (line 1152)
- [ ] Runs check procedures during editing workflow

### 11.4 `edit-store-all!` (line 1168)
- [ ] Stores both main and check combiners
- [ ] Strips `~check-` prefix from self-name in mapping position 0
- [ ] Records check hashes in main combiner lineage
- [ ] Keeps full `~check-` name for name-index registration

### 11.5 `edit-handle-failure` (line 1248)
- [ ] Handles edit failures gracefully

### 11.6 `edit-save-flow` (line 1282)
- [ ] Orchestrates parse → store → commit flow after editor save

### 11.7 `define->pretty-string` (line 1331)
- [ ] Pretty-prints a define expression to string

### 11.8 `source-extract-doc` (line 1071)
- [ ] Extracts `;;` comment documentation from source

### 11.9 `doc-lines->string` (line 1095)
- [ ] Converts doc comment lines to string

### 11.10 `doc->comment-string` (line 1106)
- [ ] Converts doc string to `;;`-prefixed comment block

**Integration Test:**
```
bb add foo.scm
EDITOR=cat bb edit foo   # prints (define foo (lambda ...))
```

---

## 12. Commands — Commit & Review

### 12.1 `command-commit` (line ~after edit)
- [ ] `bb commit foo` → calls `record-lineage!` with "commit" relation
- [ ] `bb commit --all` → commits all stored combiners
- [ ] `bb commit foo bar` → commits multiple by name
- [ ] Missing args and no `--all` → error to stderr, exit 1
- [ ] Unknown name → prints `"unknown: name"` (no exit, continues)
- [ ] Prints `"committed: name"` per success
- [ ] Prints count at end: `"N combiner(s) committed."`
- [ ] Uses `get-config-author` for author

### 12.2 `command-review` (line 2003)
- [ ] Marks combiner as reviewed via `mark-reviewed!`
- [ ] Already reviewed → prints `"already reviewed: name"` (idempotent)
- [ ] Supports multiple names in one call
- [ ] Missing args → error to stderr, exit 1
- [ ] Name resolved via name index, falls back to raw hash

---

## 13. Commands — Diff & Refactor

### 13.1 `command-diff` (line 1845)
- [ ] Compares pretty-printed surface forms of two combiners
- [ ] Identical → `"Trees are identical."`
- [ ] Different → prints `"--- name1"`, `"+++ name2"`, then line-based diff with ANSI colors
- [ ] Also shows hash-changed dependencies
- [ ] Missing args (< 2) → error to stderr, exit 1
- [ ] Name resolved via name index, falls back to raw hash

### 13.2 `diff-trees` (line 1829)
- [ ] `equal?` trees → no output (void)
- [ ] Both pairs → recurses into car and cdr with path `/car`, `/cdr`
- [ ] Leaf difference → prints `"at path: old -> new"`
- [ ] Deep nesting → path accumulates (`root/car/cdr/car`)

**Existing test:** `~check-cli-diff-trees` — covers identical and different trees.

### 13.3 `lcs-lines` (line 1683)
- [ ] Computes longest common subsequence of line lists
- [ ] Identical lists → returns full list
- [ ] Completely different → returns empty
- [ ] Overlapping sequences → correct LCS

**Existing test:** `~check-cli-lcs-lines` — covers identical, different, overlapping, and empty cases.

### 13.4 `diff-lines` (line 1726)
- [ ] Outputs unified diff with ANSI red/green coloring
- [ ] Uses `lcs-lines` for alignment

### 13.5 `diff-dependency-hashes` (line 1788)
- [ ] Compares hash references between two trees

### 13.6 `command-refactor` (line 1911)
- [ ] Replaces `(mobius-constant-ref old-hash)` with new-hash in all callers
- [ ] Recomputes hashes for updated combiners
- [ ] Cascades: if caller hash changes, its callers are also updated (worklist)
- [ ] Stores updated combiners, copies mappings, records lineage with "refactor" relation
- [ ] Carries forward check hashes in lineage
- [ ] Missing args (< 2) → error to stderr, exit 1
- [ ] Names resolved via name index, falls back to raw hash
- [ ] Prints `"refactored: name -> hash..."` per update
- [ ] Prints count: `"N combiner(s) refactored."`
- [ ] No-op when no callers reference old hash
- [ ] Optional `<at>` argument to scope refactor to specific combiner

### 13.7 `replace-ref` (line 1897)
- [ ] Replaces matching `(mobius-constant-ref old)` → `(mobius-constant-ref new)`
- [ ] Recurses into car and cdr of pairs
- [ ] Non-matching refs unchanged
- [ ] Non-pair atoms returned as-is
- [ ] Multiple occurrences all replaced

**Existing test:** `~check-cli-replace-ref` — covers basic, nested, and no-match cases.

---

## 14. Pretty-Printing Pipeline

### 14.1 `prepare-for-pretty` (line 1536)
- [ ] Replaces `#t`/`#f` with `%true`/`%false` placeholders
- [ ] Replaces `'()` with `%nil` placeholder
- [ ] Processes nested structures recursively

**Existing test:** `~check-cli-prepare-for-pretty`

### 14.2 `prepare-for-pretty-tail` (line 1557)
- [ ] Helper for tail-position preparation

### 14.3 `mobius-post-process` (line 1571)
- [ ] Restores `%true` → `#true`, `%false` → `#false`, `%nil` → `#nil`, `%void` → `#void`, `%eof` → `#eof`
- [ ] Restores unquote syntax: `,(x)`, `,x`, `,_`

**Existing test:** `~check-cli-post-process`

### 14.4 `post-process-unquotes` (line 1585)
- [ ] Restores unquote syntax in post-processed output

### 14.5 `replace-form` (line 1596)
- [ ] Replaces form patterns in expression

### 14.6 `pretty-print-one-combiner` (line 1629)
- [ ] Pretty-prints a single combiner body with its mapping
- [ ] Returns string

### 14.7 `mobius-pretty-string` (line 1641)
- [ ] Denormalizes combiner and returns pretty-printed Möbius source
- [ ] Includes doc as `;;` comments
- [ ] Appends check combiners after main define
- [ ] Prepends `~check-` to stripped check names from mapping

---

## 15. Commands — Search & Resolve

### 15.1 `command-search` (line 2030)
- [ ] Searches combiner names via `string-contains?`
- [ ] Searches mapping content via `string-contains?`
- [ ] Name match → prints `"name: <name> [hash...]"`
- [ ] Mapping match (not already shown by name) → prints `"mapping: <name>/<mapping-value>"`
- [ ] Avoids duplicate display (mapping match suppressed if name already matched)
- [ ] Missing args → error to stderr, exit 1
- [ ] Prints count: `"N result(s)."`
- [ ] No matches → `"0 result(s)."`

**Note:** Search is case-sensitive (uses `string-contains?`, not case-folding).

### 15.2 `command-resolve` (line 2083)
- [ ] Resolves a reference to its full specification (hash, language, mapping)
- [ ] Outputs resolved details

---

## 16. Commands — Worklog & Validate

### 16.1 `command-worklog` (line 2155)
- [ ] `bb worklog name "message"` → calls `add-worklog-entry!`
- [ ] `bb worklog name` (no message) → lists entries via `list-worklog-entries`
- [ ] Entries displayed as `"timestamp  message"`
- [ ] No entries → `"No worklog entries for name."`
- [ ] Missing args → error to stderr, exit 1
- [ ] Name resolved via name index, falls back to raw hash

### 16.2 `command-validate` (line 2196)
- [ ] Checks each stored combiner has a valid tree file (`file-exists?`)
- [ ] Verifies hash matches: serializes body, computes SHA-256, compares
- [ ] Detects orphaned combiners (in store but not in name index)
- [ ] Valid store → `"Store is valid. N combiner(s) stored."`
- [ ] Missing tree → `"ERROR: missing tree for name [hash...]"`
- [ ] Hash mismatch → `"ERROR: hash mismatch for name"` with expected/computed
- [ ] Orphaned → `"WARNING: orphaned combiner [hash...]"`
- [ ] Counts errors; reports total: `"N error(s) found."`
- [ ] Does not modify store (read-only operation)

---

## 17. Commands — Remote Operations

### 17.1 `command-anchor` (line 2229)
- [ ] Publishes only committed combiners (`has-committed-lineage?` check)
- [ ] Copies combiners via `copy-combiner-between-stores!`
- [ ] Copies mappings to remote store
- [ ] Ensures remote `combiners/` directory exists
- [ ] Missing args → error to stderr, exit 1
- [ ] Unknown remote name → error to stderr, exit 1
- [ ] Prints `"anchored: name"` per combiner
- [ ] Prints count: `"N combiner(s) anchored to remote."`
- [ ] Remote path from `get-config-remotes`

### 17.2 `command-remote` (line 2308)
**Subcommands:**

**`bb remote list`:**
- [ ] Shows all remotes as `"name -> path"`
- [ ] No remotes → `"No remotes configured."`

**`bb remote add <name> <path>`:**
- [ ] Adds remote to config
- [ ] Duplicate name → overwrites (filters out old, prepends new)
- [ ] Missing args (< 2) → error to stderr, exit 1
- [ ] Prints confirmation: `"Remote 'name' added -> path"`
- [ ] Persisted via `set-config-remotes!`

**`bb remote remove <name>`:**
- [ ] Removes remote from config
- [ ] Missing name → error to stderr, exit 1
- [ ] Non-existent name → silently succeeds (filter returns same list)
- [ ] Prints `"Remote 'name' removed."`

**`bb remote sync`:**
- [ ] Pulls from all configured remotes, then pushes to non-read-only remotes
- [ ] No remotes configured → `"No remotes configured."`, exit 1
- [ ] Read-only remote → pulls but skips push with `"Skipping push: remote is read-only."`
- [ ] Prints per-remote header `"Syncing 'name'..."`
- [ ] Prints `"pulled: name"` per pulled combiner
- [ ] Prints `"pushed: name"` per pushed combiner
- [ ] Prints per-remote summary: `"N pulled, M pushed."`
- [ ] Idempotent: second sync with no changes → 0 pulled, 0 pushed
- [ ] Multiple remotes → syncs each in order

**`bb remote`** (no subcommand):
- [ ] Error to stderr, exit 1

**`bb remote badcmd`:**
- [ ] Prints `"unknown subcommand 'badcmd'"`

---

## 18. ANSI Color Constants

### Line 1482–1485
- `ansi-red`, `ansi-green`, `ansi-cyan`, `ansi-reset`
- Used by `diff-lines` for colored diff output

---

## 19. Error Handling & Edge Cases

### 19.1 Argument Validation
- [ ] Every command with required args checks `(null? arguments)` or `(< (length arguments) N)`
- [ ] Error messages go to `(current-error-port)` (stderr)
- [ ] All argument errors call `(exit 1)`
- [ ] Commands accepting optional args handle both cases (e.g., `log`, `worklog`)

### 19.2 Store Resolution
- [ ] Commands requiring a store call `find-store-root`
- [ ] `find-store-root` failure → error before command logic runs
- [ ] Commands work from subdirectory of store (recursive root search)

### 19.3 Name Index Lookups
- [ ] Name-based lookup via store-derived name index
- [ ] Falls back to raw input as hash when name not found
- [ ] Invalid/non-existent hash → error from store layer (load-combiner fails)

### 19.4 File I/O
- [ ] Missing source file in `command-add` → `call-with-input-file` error
- [ ] Missing combiner tree in store → error from `load-combiner`
- [ ] Missing mapping → error from `load-first-mapping`
- [ ] Permission denied → Chez Scheme I/O error

### 19.5 Data Validation
- [ ] Invalid Scheme syntax in `command-add` → reader error
- [ ] Corrupted lineage file → `read` may fail
- [ ] Circular dependencies in `command-tree` → visited set prevents infinite loop
- [ ] Circular deps in `command-refactor` → worklist converges (hash changes stop cascading)

---

## 20. Integration Scenarios

### Scenario A: Full Lifecycle
```bash
mkdir -p /tmp/test-store && cd /tmp/test-store
bb store init
echo '(define foo (lambda (x) (+ x 1)))' > foo.scm
bb add foo.scm
bb status              # foo shows [wip]
bb commit foo
bb status              # foo shows [committed]
bb run foo 41          # 42
bb worklog foo "initial version"
bb review foo
bb status              # foo shows [committed, reviewed]
bb log foo             # shows lineage entries
bb show foo            # prints doc + (define foo (lambda ...))
bb validate            # "Store is valid."
```

### Scenario B: Refactoring Chain
```bash
# A → B → C (dependency chain)
bb add a.scm
bb add b.scm           # body references A
bb add c.scm           # body references B
bb tree B              # shows B → A
bb caller B            # shows C
bb refactor <A-hash> <A'-hash>   # cascades to B, then C
bb run C               # still works with new hashes
bb validate            # passes
```

### Scenario C: Cross-Store Publish/Sync
```bash
mkdir -p /tmp/local /tmp/remote
cd /tmp/local && bb store init
bb add foo.scm
bb commit foo
bb remote add origin /tmp/remote
bb anchor origin       # copies committed combiner
bb remote list          # shows origin

cd /tmp/remote && bb store init
bb remote add upstream /tmp/local
bb remote sync          # pulls foo from all remotes, pushes committed
bb run foo              # works
bb remote sync          # idempotent: 0 pulled, 0 pushed
```

### Scenario D: Search and Diff
```bash
bb add foo-map.scm
bb add foo-fold.scm
bb add bar-helper.scm
bb search foo           # finds foo-map, foo-fold
bb diff foo-map foo-fold  # shows structural differences
```

### Scenario E: Edit Round-Trip
```bash
bb add my-fn.scm
EDITOR=cat bb edit my-fn > /tmp/my-fn-edited.scm
bb add /tmp/my-fn-edited.scm
bb diff my-fn my-fn-v2  # "Trees are identical." (round-trip preserves structure)
```

### Scenario F: Edit with Checks
```bash
# File contains (define foo ...) and (define ~check-foo-00 ...)
bb add foo-with-checks.scm
bb edit foo             # shows both main and check defines
# Checks stored with stripped name in mapping, reconstituted with ~check- prefix
```

### Scenario G: REPL Session
```bash
echo -e '(+ 2 3)\n(define x 10)\n(* x x)' | bb repl
# Output:
# bb repl — Mobius Seed v0.2.0
# ...
# 5
# bb> bb> 100
```

### Scenario H: Eval Expressions
```bash
bb eval '(+ 2 3)'                    # 5
bb eval '(define f (lambda (x) (* x x))) (f 7)'  # 49
bb eval '(if #true 1 2)'             # 1
bb eval '#nil'                       # #nil
```

### Scenario I: Multi-Language Support
```bash
bb add double.fr.scm fr
bb add double.en.scm en
bb show doubler@fr      # shows French version
bb show doubler@en      # shows English version
```

---

## 21. Regression Tests

- [ ] All existing `~check-*` tests pass (`binink check .`)
- [ ] Store layout uses flat hash directories (no two-char prefix split)
- [ ] Denormalization round-trip: `add → edit → add` produces same hash
- [ ] All 25 commands listed in `print-usage` match dispatch table
- [ ] Transcript tests in `tests/*.md` still pass
- [ ] `~check-` prefix correctly stripped in mappings, reconstituted on read

---

## 22. Performance Benchmarks (Optional)

- [ ] `bb add` with large combiner (1000+ lines)
- [ ] `bb tree` with deep dependency chain (10+ levels)
- [ ] `bb refactor` with many callers (100+ combiners)
- [ ] `bb search` with 1000+ registered combiners
- [ ] `bb validate` with 1000+ combiners
- [ ] `load-index-into-env` with 100+ entries

---

## 23. Existing Unit Tests

### Currently exported from `(bb cli)`:
| Test | What it covers | Line |
|------|---------------|------|
| `~check-cli-build-argument-tree` | `build-argument-tree` — argument tree construction from list | 2425 |
| `~check-cli-mobius-write-surface` | `mobius-write-surface` — surface syntax output for integers, `,x`, `,(x)`, `,_`, lists | 2435 |
| `~check-cli-replace-ref` | `replace-ref` — hash replacement in trees (basic, nested, no-match) | 2468 |
| `~check-cli-diff-trees` | `diff-trees` — identical trees (no output) and different trees (output with paths) | 2485 |
| `~check-cli-prepare-for-pretty` | `prepare-for-pretty` — boolean/nil placeholder replacement, string helpers | 2500 |
| `~check-cli-post-process` | `mobius-post-process` — placeholder restoration, unquote syntax | 2524 |
| `~check-cli-lcs-lines` | `lcs-lines` — LCS algorithm, `diff-lines` output | 2541 |
| `~check-cli-resolve-ref` | `resolve-ref` — 12 resolution cases including multi-part refs, ambiguity, timestamps | 2562 |
| `~check-cli-show` | `command-show` pipeline — basic and inline denormalization modes | 2673 |
| `~check-cli-print` | `command-print` — hash disambiguation, duplicate name handling | 2725 |

### Suggested new `~check-*` tests:
| Test | What it would cover |
|------|-------------------|
| `~check-cli-mobius-display-value` | All branches of `mobius-display-value` (nil, void, eof, bool, string, char, int, float, pairs, combiners) |
| `~check-cli-string-helpers` | `string-trim`, `string-contains?`, `string-split-at-sign`, `string-replace`, `string-split-lines` edge cases |
| `~check-cli-extract-refs` | `extract-refs` and `extract-named-refs` — constant-ref extraction from trees |
| `~check-cli-make-hash-to-name` | `make-hash->name` — reverse lookup from name index |
| `~check-cli-classify-defines` | `classify-defines` — main vs check define separation |
| `~check-cli-doc-helpers` | `source-extract-doc`, `doc-lines->string`, `doc->comment-string` |

---

## 24. Testing Approach

### Unit Tests (via `~check-*`)
In-module test procedures discovered and run by `binink check .`.

### Integration Tests (via bash transcript tests)
- `tests/*.md` files with fenced `scheme` and `bash` blocks
- Run by `transcript.scm`, wired into `binink check`

### Manual Testing
```bash
# Run all unit tests
binink check . --fail-fast

# Run a specific command manually
bb eval '(+ 2 3)'

# Test add with language
bb add double.fr.scm fr
```

---

## 25. Coverage Map

Every function defined in `cli.scm` and which plan section covers it:

| Function | Line | Section | Has `~check-*`? |
|----------|------|---------|-----------------|
| `bb-version` | 54 | §1.3 | — |
| `print-usage` | 56 | §1.2 | — |
| `command-eval` | 97 | §6.1 | — |
| `mobius-display-value` | 111 | §2 | suggested |
| `mobius-write-surface` | 146 | §3 | **yes** |
| `command-repl` | 190 | §6.2 | — |
| `string-trim` | 229 | §4.1 | suggested |
| `read-line` | 244 | §4.2 | — |
| `string-contains?` | 256 | §4.3 | suggested |
| `resolve-hash-only` | 266 | §5.3 | — |
| `string-split-at-sign` | 281 | §4.4 | — |
| `looks-like-lang?` | 295 | §5.2 | **yes** (in resolve-ref) |
| `resolve-name-to-hash` | 304 | §5.4 | — |
| `resolve-ref` | 341 | §5.1 | **yes** |
| `resolve-ref-mapping` | 402 | §5.1 | — |
| `make-name-lookup` | 444 | §5.5 | — |
| `make-hash->name` | 542 | §5.6 | suggested |
| `load-combiner-value` | 560 | §5.8 | — |
| `load-index-into-env` | 569 | §5.9 | — |
| `command-store-init` | 603 | §7.1 | — |
| `command-store-info` | 642 | §7.2 | — |
| `command-status` | 666 | §7.3 | — |
| `extract-refs` | 697 | §5.10 | suggested |
| `shortest-unique-prefix` | 710 | §5.7 | **yes** (in print) |
| `command-print` | 722 | §10.3 | **yes** |
| `show-combiner-with-mapping` | 826 | §10.2 | — |
| `command-show` | 845 | §10.1 | **yes** |
| `command-tree` | 857 | §8.1 | — |
| `command-caller` | 900 | §8.2 | — |
| `list-lineage-files` | 933 | §9.1 | — |
| `load-lineage-record` | 943 | §9.2 | — |
| `command-log` | 949 | §9.3 | — |
| `command-run` | 1021 | §6.4 | — |
| `source-extract-doc` | 1071 | §11.8 | suggested |
| `doc-lines->string` | 1095 | §11.9 | — |
| `doc->comment-string` | 1106 | §11.10 | — |
| `string-trim-whitespace` | 1117 | §4.7 | — |
| `classify-defines` | 1136 | §11.2 | suggested |
| `edit-run-checks` | 1152 | §11.3 | — |
| `edit-store-all!` | 1168 | §11.4 | — |
| `edit-handle-failure` | 1248 | §11.5 | — |
| `edit-save-flow` | 1282 | §11.6 | — |
| `define->pretty-string` | 1331 | §11.7 | — |
| `command-edit` | 1346 | §11.1 | — |
| `ansi-red` | 1482 | §18 | — |
| `ansi-green` | 1483 | §18 | — |
| `ansi-cyan` | 1484 | §18 | — |
| `ansi-reset` | 1485 | §18 | — |
| `string-replace` | 1492 | §4.5 | — |
| `string-split-lines` | 1514 | §4.6 | — |
| `prepare-for-pretty` | 1536 | §14.1 | **yes** |
| `prepare-for-pretty-tail` | 1557 | §14.2 | — |
| `mobius-post-process` | 1571 | §14.3 | **yes** |
| `post-process-unquotes` | 1585 | §14.4 | — |
| `replace-form` | 1596 | §14.5 | — |
| `pretty-print-one-combiner` | 1629 | §14.6 | — |
| `mobius-pretty-string` | 1641 | §14.7 | — |
| `lcs-lines` | 1683 | §13.3 | **yes** |
| `diff-lines` | 1726 | §13.4 | — |
| `extract-named-refs` | 1780 | §5.11 | — |
| `diff-dependency-hashes` | 1788 | §13.5 | — |
| `diff-trees` | 1829 | §13.2 | **yes** |
| `command-diff` | 1845 | §13.1 | — |
| `replace-ref` | 1897 | §13.7 | **yes** |
| `command-refactor` | 1911 | §13.6 | — |
| `command-review` | 2003 | §12.2 | — |
| `command-search` | 2030 | §15.1 | — |
| `command-resolve` | 2083 | §15.2 | — |
| `command-worklog` | 2155 | §16.1 | — |
| `command-validate` | 2196 | §16.2 | — |
| `command-anchor` | 2229 | §17.1 | — |
| `command-remote` | 2308 | §17.2 | — |
| `main` | 2370 | §1.1 | — |

---

## Success Criteria

- All existing `~check-*` tests pass (10 tests)
- All commands have documented test cases
- No crashes on invalid input (every command has error-path tests)
- Clear error messages for all failure cases (stderr + exit 1)
- All integration scenarios complete successfully
- Coverage map accounts for every `define` in `cli.scm` (74 functions)
- Store uses flat hash directories (no two-char prefix split)
