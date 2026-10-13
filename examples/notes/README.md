# notes — folder-based note-taking webui

A server-rendered note-taking app served by `bb serve`. Notes are
organized into folders and written in a subset of markdown; the editor
has a Preview button that round-trips through the server — no
JavaScript anywhere.

## What it demonstrates

- **Pure Mobius combiners, composed via the store** — 29 committed
  combiners in a dependency graph (`./bb tree notes`). Nothing but the
  base library, primitives, `xeno` calls into Chez Scheme builtins, and
  each other.

- **`gamma` pattern matching for real work** — `md-escape-chars` and
  `form-decode-chars` walk character lists clause by clause;
  `md-flush` dispatches on the block-mode string; `hex-digit` is a
  22-clause character classifier.

- **A markdown renderer written from scratch** — `md-render` supports
  `#`/`##`/`###` headings, `- ` bullet lists, blank-line-separated
  paragraphs, `**bold**`, `*italic*`, `` `code` ``, and
  `[text](url)`. HTML special characters are always escaped first, so
  note bodies cannot inject markup.

- **Form handling without a framework** — `form-get` parses
  `application/x-www-form-urlencoded` POST bodies and percent-decodes
  them (`+` → space, `%XX` → character), all in Mobius.

- **The two-combiner server interface** — `notes-state` builds shared
  state once (`box` of `#(next-id folders notes)`); `notes` handles
  every request with `(state req)`.

- **Server-side preview** — the editor's Preview button uses HTML5
  `formaction`/`formmethod` to POST the same form to `/preview`, which
  re-renders the editor prefilled with a rendered-markdown panel above
  it. Save returns to the same editor.

## Routes

```
GET  /                      folder overview (+ create-folder form)
GET  /folder/<name>         notes of a folder
GET  /note/<id>              note rendered as markdown
GET  /new?folder=<name>     editor (create)
GET  /edit/<id>             editor (edit, prefilled)
POST /add                   create note       -> 302 /note/<id>
POST /save                  update note       -> 302 /note/<id>
POST /preview               editor + rendered markdown (no save)
POST /delete                remove note       -> 302 /folder/<name>
POST /folder-add            create folder     -> 302 /
```

Folder names are restricted to `[a-zA-Z0-9_-]`; anything else is
silently ignored. Notes live in server memory for the lifetime of the
process — refresh-safe, restart-lost, like the counter example.

## How to run

```sh
cd examples/notes

# 1. Build the store (idempotent — safe to re-run; combiners are
#    added in dependency order)
./bb-add-all.sh

# 2. Start the server
./bb serve notes-state notes --port 8080

# 3. Open in a browser
#    http://localhost:8080/
```

Create a note, write some markdown, press Preview, edit, press Save.

## Combiner map

| Area | Combiners |
|------|-----------|
| Markdown escaping | `md-escape-chars` (gamma), `md-escape` |
| Markdown inline | `md-next-marker`, `md-find-pair`, `md-inline-from`, `md-inline`, `md-inline-join` |
| Markdown blocks | `md-index-of`, `md-prefix?`, `md-split-lines`, `md-reverse`, `md-ul-items`, `md-flush` (gamma), `md-blocks`, `md-render` |
| Form decoding | `hex-digit` (gamma), `form-decode-chars` (gamma), `form-decode`, `form-get-scan`, `form-get` |
| Notes model/UI | `notes-name-ok?`, `notes-count-folder`, `notes-render-folders`, `notes-render-notes`, `notes-folder-options`, `notes-page`, `notes-editor` |
| Application | `notes-state` (app factory), `notes` (request handler) |

Explore the graph:

```sh
./bb tree notes        # dependency tree of the handler
./bb caller md-inline  # who calls md-inline
./bb status
```

## Notes on the platform

- Multi-segment request paths arrive from `transparenturing` with
  doubled separators (`/folder//name`), and the root path is `""` —
  the handler normalizes for this.
- Base-library combiners (`not`, `list`, ...) are not resolvable at
  normalization time; stored combiners may only reference primitives,
  `xeno`, and previously committed combiners.
- The store is append-only: re-adding a changed combiner produces a
  new hash, and dependents must be re-added in order to pick it up
  (`./bb tree notes` shows the current closure).
