# The Invariant

A trilingual (en/fr/es) static blog about building a self-sufficient
software system in a confined Earth analog (the Hold) and carrying it
on a deep-space mission where Earth is unreachable. Written and
generated entirely with `bb` and Möbius — the meta-story of the blog
*is* the project.

The personas of `MANUAL.md` are recurring characters. The store is the
infrastructure of the fiction.

## Structure

```
invariant/
  bb                       # wrapper: invokes scheme with the right libdir
  bb-add-all.sh            # rebuilds the combiner store from src/
  config.scm, combiners/   # the mobius-store
  PHASE0.md                # findings from the spike (xeno, mappings, perf)
  src/
    util/        list-of, mob-append, str-append, string-join, str-concat,
                 escape-html(-char,-loop,-fn)        — pure Möbius helpers
    site/        site-meta, site-title/tagline/footer, style-css
    render/      post accessors, render-paragraphs, render-post,
                 lang-switcher, render-page, render-toc-{entry,list},
                 render-index
    io/          write-file, ensure-dir   — the only xeno surface
    posts/{en,fr,es}/  six post combiners (Phase 1 thin slice)
    manifest{,-en,-fr,-es}.scm
    generate{,-posts,-index}.{en,fr,es}.scm
  out/                     # generated site (gitignored)
```

## Build

```sh
./bb-add-all.sh           # idempotent; safe to re-run
./bb run generate "en"
./bb run generate "fr"
./bb run generate "es"
xdg-open out/en/index.html
```

For a clean build (only inside `invariant/`; never delete `combiners/`
at the bb-dev repo root — that's the bb internal store):

```sh
cd path/to/north/invariant       # important: not the repo root
rm -rf out/ combiners/ reviewed/ worklog/
./bb store init .
./bb-add-all.sh
./bb run generate "en"
./bb run generate "fr"
./bb run generate "es"
```

(Tested from a fresh `/tmp/inv-clean` — passes end-to-end.)

## Multilingual surface

User-facing combiners are mapped in en/fr/es with the same SHA-256:

| English      | français          | español           |
|--------------|-------------------|-------------------|
| `generate`   | `engendrer`       | `engendrar`       |
| `render-post`| `afficher-recit`  | `mostrar-relato`  |
| `render-page`| `afficher-page`   | `mostrar-pagina`  |
| `render-index`| `afficher-index` | `mostrar-indice`  |

`bb resolve generate` lists all three names; `bb show generate@fr`
renders the French source. By default `bb run generate` resolves to
the preferred-language name (configured via `(languages "en" "fr" "es")`
in `config.scm` — first entry wins).

Helpers (`str-append`, `escape-html`, etc.) live in English only —
this is a bb name-index limitation; see PHASE0.md, section 0b.

## The xeno boundary

`xeno` calls Chez Scheme. The user's instruction was "use it with
care, only when there is no other way." It appears in exactly two
files, both in `src/io/`:

```sh
grep -rn 'xeno' src/
# src/io/ensure-dir.en.scm:    (xeno "system" "mkdir -p ...")
# src/io/write-file.en.scm:    (xeno "system" "rm -f ...")
#                              (xeno "open-output-file" path)
#                              (xeno "put-string" port contents)
#                              (xeno "close-output-port" port)
```

Everything else — list traversal, string composition, HTML
construction, language dispatch — is pure Möbius.

## Status

Phase 0 (spikes) and Phase 1 (generator + 2 stories per language)
complete. Phase 2 (28 more chapters in 3 languages) pending sign-off
on tone and layout from the rendered Phase-1 output.

## A note on bb

A small bb fix landed during Phase 1: `load-combiner-value` used
`store-load-first-mapping` (filesystem order) while the name index
used `store-load-preferred-mapping` (config-order). When a combiner
had multiple language mappings the loader could pick a name not in
the index, producing a spurious unbound-variable error. The fix is a
one-symbol change in `src/bb/cli.scm`. See PHASE0.md.
