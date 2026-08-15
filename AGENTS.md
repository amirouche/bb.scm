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

## Conventions

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
