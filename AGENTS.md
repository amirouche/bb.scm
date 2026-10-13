# AGENTS.md

## Project

bb (Mobius Seed) is a content-addressed programming language and knowledge
store written in Chez Scheme (R6RS). It separates code identity (logic hashed
via SHA-256 after de Bruijn normalization) from presentation (variable names,
language), enabling multilingual programming with authorship/lineage tracking.

## Getting started

Requires the letloop toolchain, built from the submodule. From a fresh clone:

```bash
git submodule update --init

# Build Chez Scheme from source and the letloop binary (uses ~15 cores)
make -C submodules/letloop chezscheme SCHEME=$(which scheme)
make -C submodules/letloop letloop    SCHEME=$(which scheme)
```

The built-from-source Chez Scheme and the letloop binary install into
`submodules/letloop/local/`. The letloop binary is at
`submodules/letloop/local/bin/letloop`.

The system-installed `scheme` (on PATH) is used only as the bootstrap compiler
for building Chez from source. Programs run against the locally built Chez
through the letloop binary, which carries its own boot image.

### FFI dependencies

transparenturing eagerly loads shared libraries (`liburing-ffi.so.2`,
`libtls.so`). Build them from source:

```bash
make -C submodules/letloop dependencies
```

This builds liburing (2.14, with unreleased functions transparenturing needs),
argon2, blake3, picohttpparser, sodium, oprf, and opaque into
`submodules/letloop/local/lib/`. `libtls.so` must come from the system
(`libtls-dev` package on Ubuntu).

All letloop commands that import transparenturing (compile, check, exec,
serve) must run with `LD_LIBRARY_PATH` pointing to the locally built
libraries:

```bash
export LD_LIBRARY_PATH=$(pwd)/submodules/letloop/local/lib/
```

## Running bb

### Interpreted (no compilation, for development)

```bash
submodules/letloop/local/bin/letloop exec src/ src/bb/cli.scm main -- eval '(+ 1 2)'
submodules/letloop/local/bin/letloop exec src/ src/bb/cli.scm main -- repl
```

Arguments after `--` are passed to bb's `main` as command-line arguments.

### Compiled standalone binary

```bash
submodules/letloop/local/bin/letloop compile --visible-libraries src/ src/bb/cli.scm main
./a.out eval '(+ 1 2)'
```

This produces `./a.out`, a self-contained ELF binary (host: `letloop-main.c`,
boot: the amalgamated boot image with petite.boot + scheme.boot folded in).
No `scheme` on PATH, no `--libdirs` needed at run time.

`--visible-libraries` is required: bb resolves library names at runtime via
`eval`/`environment` (the `xeno` primitive, the `serve` command). Without it,
libraries are folded into the whole program and their names are not resolvable
at runtime.

The default optimization level is 0 (safe, debuggable). For higher
optimization, pass `--optimize-level=3`:

```bash
submodules/letloop/local/bin/letloop compile --visible-libraries --optimize-level=3 src/ src/bb/cli.scm main
```

### Fallback: exec --dev

If the compiled binary crashes or misbehaves and you need debug information
(allocation counts, instruction counts, source-level profile, debug on
exception), run interpreted with `--dev`:

```bash
submodules/letloop/local/bin/letloop exec --dev src/ src/bb/cli.scm main -- eval '(+ 1 2)'
```

`--dev` sets its own optimize level and cannot be combined with
`--optimize-level`.

## Build artifacts

- `*.so` and `*.wpo` — compiled library objects, gitignored.
- `a.out` and `a.out.boot` — standalone binary output from `letloop compile`.
- `submodules/letloop/local/` — the locally built Chez Scheme, letloop binary,
  and cached libraries.

## Multi-agent workflow

Multiple agents may work in the same store, in the same directory, without
coordination. The rules below divide into what the platform enforces (the
store makes them unbreakable) and what remains discipline.

### Identity

- Set `BB_AUTHOR` to a distinct identity for each agent sharing one store.
  Every lineage record, worklog entry, and review carries it. Without it,
  per-agent semantics are vacuous (one `config.scm` author for everyone).
- Never coordinate on names. Names are presentation; identity is the hash of
  the normalized tree. Same logic converges to the same SHA-256 and dedupes
  (a re-add becomes a mapping/translation); different logic under the same
  name coexists as `name@hashA` / `name@hashB`.

### Planning

- Plan the DAG, not the files: one define per combiner; dependencies must be
  added before dependents (the store enforces this — `bb add` fails with
  `unbound variable` otherwise). Mutual recursion across combiners is
  therefore impossible; the graph is a DAG by construction.
- The contract between agents is a check suite (`bb add --check`), not a
  name, not a file. A node without checks has no interface.
- Assign a node only once its dependencies are committed. Task = "produce a
  combiner that passes checks X, depending only on hashes H1..Hn".

### Authoring

- Check what exists first (`bb search`, `bb tree`); don't re-solve.
- Stored combiners may only reference primitives, `xeno`, and previously
  committed combiners — base-library names (`not`, `list`, ...) do not
  resolve at normalization time.
- Small combiners; `bb caller` measures any change's blast radius.
- Racing the same combiner name between agents: the store keeps both
  identities (`name@hashA` / `name@hashB`), but the flat source file is
  shared — last writer wins at the filesystem. Author same-name combiners
  in per-agent source files (e.g. `duration-parse-racer.en.scm`); the
  store arbitrates identity, the filesystem does not.

### Promotion

- Each agent commits only their own work: `BB_AUTHOR=<me> bb commit --mine`.
  `--all` sweeps every staged record including peers' in-flight work; it is
  for single-agent stores or a deliberate, announced integrator pass.
- After `bb commit --mine`, the agent records a worklog entry on every
  committed combiner describing itself, the task, and the outcome:
  `bb worklog <ref> "author: <me> | task: <assigned task, in one sentence> |
  done: <what was achieved, incl. checks passed>"`. Worklog entries do not
  record `BB_AUTHOR` — the entry only stores combiner, message, timestamp —
  so the identity must be stated in the message text. The automatic entry
  written by `bb commit` ("committed <name> (<relation>)") says what
  happened, not who did it or why; without the follow-up entry, a peer
  reading the store cannot tell agents apart in the worklog or reconstruct
  which task a combiner was produced for.

### Integration

- Merging is `remote pull` — a set union of immutable objects. There is no
  merge step to perform. Alternatives are arbitrated by `bb check`, not by
  discussion.
- An upstream change produces a new hash; `bb caller` lists every dependent
  that must be re-added against it. That list is the re-tasking queue —
  assign it, don't negotiate it.
- Serialize the mutable edges: `config.scm`, `bb remote add`, `published/`.
  These are the only genuinely shared mutable files.

## Conventions

### Task tracking

All tasks that remain to be done are recorded in `TODO/` as one file
per task, named `AWA<hex>-<slug>.md` where `<hex>` is a four-digit
uppercase hexadecimal number (AWA0000, AWA0001, ... AWA0009, AWA000A,
... AWA000F, AWA0010, ...). Each file contains, in this order:

- `Number:` the AWA identifier (matches the filename)
- `Title:` the task title
- `Status:` todo | doing | done
- `## Abstract` — what the task delivers, in a few sentences
- `## Context` — why it matters; evidence, examples, prior discussion
- `## Description` — what to build, concretely, with integration points
- `## Proposals` — ranked candidate approaches

Do not record new work as free-form bullets; `TODO.md` at the repo root
is the legacy list — when an item there is picked up, migrate it to an
AWA file rather than editing it in place.

### Naming

Never use shorthand or abbreviations in combiner names. Write
`markdown-write`, `markdown-read`, `markdown->html` — not `md-write`,
`md-read`, `md-html`. Use `->` for conversions (`markdown->html`), and full
words everywhere else (`form-decode`, not `frm-dec`).

Names cost nothing: they are erased at normalization (identity is the hash),
so terseness saves no bytes and no time. Full words are what `bb search`
matches against, what mappings carry across languages, and what another
agent reads before `bb show`. Abbreviations only exist to be decoded.

Procedure names follow the type-name-verb or type-name-verb-complement
pattern, read left to right: the domain type first, then the object it
works on, then the verb, then an optional complement — `store-load-combiner`,
`notes-count-folder`, `form-decode-chars`, `name-environment-extend`
(compound type names are fine). Accessors may end in the returned noun
(`store-combiner-tree-path`), mutators end in `!` (`store-mapping!`),
predicates in `?` (`notes-name-ok?`).

Variables holding objects are plain nouns — `folders`, `handler`, `state`,
`body`, `note-entry` — never verb phrases.

Use [conventional commits](https://www.conventionalcommits.org/) for all
commit messages:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`,
`ci`, `style`.

Examples:

```
feat(serve): call server-start! in-process instead of shelling out to scheme
fix(store): validate hash prefixes to prevent path traversal
docs: add AGENTS.md with build and run instructions
chore: add letloop submodule
```
