# The Invariant

A trilingual (en/fr/es) static blog about building a self-sufficient
software system in a confined Earth analog (the Hold) and carrying it
on a deep-space mission where Earth is unreachable. Written and
generated entirely with `bb` and Möbius — the meta-story of the blog
*is* the project.

The personas of `MANUAL.md` are recurring characters. The store is the
infrastructure of the fiction.

**Deployed at [https://hyper.dev/mobius/the-invariant/](https://hyper.dev/mobius/the-invariant/)**

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
    site/        site-meta, site-title/tagline/footer, style-css, site-base
    render/      post accessors, render-paragraphs, render-post,
                 lang-switcher, render-page, render-toc-{entry,list},
                 render-index, render-root-index
    io/          write-file, ensure-dir   — the only xeno surface
    posts/{en,fr,es}/  30 post combiners per language (Phase 2)
    manifest{,-en,-fr,-es}.scm
    generate{,-posts,-index}.{en,fr,es}.scm
  out/                     # generated site (gitignored)
```

## Build

```sh
./bb-add-all.sh           # idempotent; safe to re-run
./bb run generate "en"
./bb run engendrer "fr"
./bb run engendrar "es"
xdg-open out/index.html
```

For a clean build (only inside `invariant/`; never delete `combiners/`
at the bb-dev repo root — that's the bb internal store):

```sh
cd path/to/north/invariant       # important: not the repo root
rm -rf out/ combiners/ reviewed/ worklog/
./bb store init .
./bb-add-all.sh
./bb run generate "en"
./bb run engendrer "fr"
./bb run engendrar "es"
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

`bb resolve generate` shows the English mapping. `engendrer` and `engendrar`
are separate combiners (not alternate-language mappings of the same hash),
because `generate` writes `out/index.html` via `render-root-index` while the
FR/ES variants do not.

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

Phase 0 (spikes), Phase 1 (generator + 2 stories per language), and Phase 2
(30 stories per language in en/fr/es) complete. The generated site is rooted
at `/mobius/the-invariant/` via the `site-base` combiner; `out/index.html` is
the language-selector entry point written by `generate "en"`.

## Notes on bb fixes

Two fixes landed in `src/bb/cli.scm` during this project:

1. **Phase 1:** `load-combiner-value` used `store-load-first-mapping`
   (filesystem order) while the name index used `store-load-preferred-mapping`
   (config-order). The mismatch caused spurious unbound-variable errors when a
   combiner had multiple language mappings. Fixed to use `store-load-preferred-mapping`.

2. **Phase 2:** When two versions of a self-recursive combiner share a name,
   `store-build-name-index` registers only the *qualified* name
   (`name@shortHash`) in the index. The self-reference (de Bruijn index 0) was
   still denormalized to the *unqualified* name from the mapping, which is not
   bound in the environment. Fixed: `load-combiner-value` now overrides mapping
   entry 0 with the qualified name when the hash's index entry differs from the
   mapping's base name.
