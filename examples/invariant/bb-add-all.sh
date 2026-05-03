#!/bin/sh
# Rebuild the Invariant combiner set from src/.  Idempotent: re-runs
# against an existing store no-op the duplicate hashes (bb add reuses
# the combiner directory; only adds a new mapping if one is missing).
#
# Order matters: each combiner's dependencies must be registered first.
# The order below mirrors the dependency DAG:
#   util base   ->  list-of, mob-append, str-append, string-join, str-concat,
#                   escape-html-char, escape-html-loop, escape-html
#   site        ->  site-meta, site-title/tagline/footer, style-css, site-base
#   render      ->  post-* accessors, render-paragraphs, render-post,
#                   lang-switcher, render-page, render-toc-*, render-index,
#                   render-root-index
#   io          ->  write-file, ensure-dir
#   posts       ->  18 (3 langs x 2) post combiners
#   manifests   ->  manifest-en/fr/es, manifest dispatcher
#   generator   ->  generate-posts, generate-index, generate (en/fr/es)
#
# Run from north/invariant/.  Uses ./bb (which points at ../src for libdirs).
set -eu

bb=./bb

add()  { lang="${2:-en}"; "$bb" add "$1" "$lang" >/dev/null; }
done_round() { "$bb" commit --all >/dev/null; }

echo ">> util"
add src/util/list-of.en.scm
add src/util/mob-append.en.scm
done_round
add src/util/str-append.en.scm
done_round
add src/util/string-join.en.scm
done_round
add src/util/str-concat.en.scm
add src/util/escape-html.en.scm
done_round
add src/util/escape-html-impl.en.scm
done_round
add src/util/escape-html-fn.en.scm
done_round

echo ">> site"
add src/site/site-meta.en.scm
done_round
add src/site/site-meta-helpers.en.scm
add src/site/style-css.en.scm
add src/site/site-base.en.scm
done_round

echo ">> render"
add src/render/post-accessors.en.scm
add src/render/render-paragraphs.en.scm
done_round
add src/render/render-post.en.scm
add src/render/render-post.fr.scm fr
add src/render/render-post.es.scm es
done_round
add src/render/lang-switcher.en.scm
done_round
add src/render/render-page.en.scm
add src/render/render-page.fr.scm fr
add src/render/render-page.es.scm es
done_round
add src/render/render-toc-entry.en.scm
add src/render/render-toc-list.en.scm
done_round
add src/render/render-index.en.scm
add src/render/render-index.fr.scm fr
add src/render/render-index.es.scm es
add src/render/render-root-index.en.scm
done_round

echo ">> io"
add src/io/write-file.en.scm
add src/io/ensure-dir.en.scm
done_round

echo ">> posts (en first, then fr/es with translate edges)"
add src/posts/en/01-the-hold.en.scm        en
add src/posts/en/02-the-hacker.en.scm      en
add src/posts/en/03-the-polyglot.en.scm    en
add src/posts/en/04-the-senior.en.scm      en
add src/posts/en/05-the-kid.en.scm         en
done_round
add src/posts/en/06-the-theorist.en.scm    en
add src/posts/en/07-the-coordinator.en.scm en
add src/posts/en/08-the-thinker.en.scm     en
add src/posts/en/09-the-air-cycle.en.scm   en
add src/posts/en/10-the-check.en.scm       en
done_round
add src/posts/en/11-departure.en.scm       en
add src/posts/en/12-the-privateer.en.scm   en
add src/posts/en/13-the-citizen.en.scm     en
add src/posts/en/14-the-educator.en.scm    en
add src/posts/en/15-the-connector.en.scm   en
done_round
add src/posts/en/16-the-symbiotic.en.scm      en
add src/posts/en/17-the-anchor-backlog.en.scm en
add src/posts/en/18-the-refactor.en.scm       en
add src/posts/en/19-the-memory-wipe.en.scm    en
add src/posts/en/20-the-artist.en.scm         en
done_round
add src/posts/en/21-the-silence.en.scm        en
add src/posts/en/22-the-stolen.en.scm         en
add src/posts/en/23-the-researcher.en.scm     en
add src/posts/en/24-the-steward.en.scm        en
add src/posts/en/25-the-academic.en.scm       en
done_round
add src/posts/en/26-the-representative.en.scm en
add src/posts/en/27-the-manifesto.en.scm      en
add src/posts/en/28-the-invariant.en.scm      en
add src/posts/en/29-the-language.en.scm       en
add src/posts/en/30-the-first-commit.en.scm   en
done_round
"$bb" add src/posts/fr/01-la-cale.fr.scm            fr --derived-from=post-01-the-hold-en     --relation=translate >/dev/null
"$bb" add src/posts/fr/02-le-bricoleur.fr.scm        fr --derived-from=post-02-the-hacker-en   --relation=translate >/dev/null
"$bb" add src/posts/fr/03-la-polyglotte.fr.scm       fr --derived-from=post-03-the-polyglot-en --relation=translate >/dev/null
"$bb" add src/posts/fr/04-le-veteran.fr.scm          fr --derived-from=post-04-the-senior-en   --relation=translate >/dev/null
"$bb" add src/posts/fr/05-la-gamine.fr.scm           fr --derived-from=post-05-the-kid-en      --relation=translate >/dev/null
done_round
"$bb" add src/posts/fr/06-le-theoricien.fr.scm       fr --derived-from=post-06-the-theorist-en    --relation=translate >/dev/null
"$bb" add src/posts/fr/07-la-coordinatrice.fr.scm    fr --derived-from=post-07-the-coordinator-en --relation=translate >/dev/null
"$bb" add src/posts/fr/08-le-penseur.fr.scm          fr --derived-from=post-08-the-thinker-en     --relation=translate >/dev/null
"$bb" add src/posts/fr/09-le-cycle-air.fr.scm        fr --derived-from=post-09-the-air-cycle-en   --relation=translate >/dev/null
"$bb" add src/posts/fr/10-la-verification.fr.scm     fr --derived-from=post-10-the-check-en       --relation=translate >/dev/null
done_round
"$bb" add src/posts/fr/11-le-depart.fr.scm           fr --derived-from=post-11-departure-en        --relation=translate >/dev/null
"$bb" add src/posts/fr/12-le-corsaire.fr.scm         fr --derived-from=post-12-the-privateer-en    --relation=translate >/dev/null
"$bb" add src/posts/fr/13-la-citoyenne.fr.scm        fr --derived-from=post-13-the-citizen-en      --relation=translate >/dev/null
"$bb" add src/posts/fr/14-l-educatrice.fr.scm        fr --derived-from=post-14-the-educator-en     --relation=translate >/dev/null
"$bb" add src/posts/fr/15-la-relieuse.fr.scm         fr --derived-from=post-15-the-connector-en    --relation=translate >/dev/null
done_round
"$bb" add src/posts/fr/16-l-ia-symbiotique.fr.scm    fr --derived-from=post-16-the-symbiotic-en      --relation=translate >/dev/null
"$bb" add src/posts/fr/17-l-arriere-ancre.fr.scm     fr --derived-from=post-17-the-anchor-backlog-en --relation=translate >/dev/null
"$bb" add src/posts/fr/18-la-cascade.fr.scm          fr --derived-from=post-18-the-refactor-en       --relation=translate >/dev/null
"$bb" add src/posts/fr/19-l-effacement.fr.scm        fr --derived-from=post-19-the-memory-wipe-en    --relation=translate >/dev/null
"$bb" add src/posts/fr/20-l-artiste.fr.scm           fr --derived-from=post-20-the-artist-en         --relation=translate >/dev/null
done_round
"$bb" add src/posts/fr/21-le-silence.fr.scm          fr --derived-from=post-21-the-silence-en        --relation=translate >/dev/null
"$bb" add src/posts/fr/22-celle-qu-on-a-volee.fr.scm fr --derived-from=post-22-the-stolen-en         --relation=translate >/dev/null
"$bb" add src/posts/fr/23-le-chercheur.fr.scm        fr --derived-from=post-23-the-researcher-en     --relation=translate >/dev/null
"$bb" add src/posts/fr/24-la-gardienne.fr.scm        fr --derived-from=post-24-the-steward-en        --relation=translate >/dev/null
"$bb" add src/posts/fr/25-la-chercheuse.fr.scm       fr --derived-from=post-25-the-academic-en       --relation=translate >/dev/null
done_round
"$bb" add src/posts/fr/26-le-representant.fr.scm     fr --derived-from=post-26-the-representative-en --relation=translate >/dev/null
"$bb" add src/posts/fr/27-le-manifeste.fr.scm        fr --derived-from=post-27-the-manifesto-en      --relation=translate >/dev/null
"$bb" add src/posts/fr/28-l-invariant.fr.scm         fr --derived-from=post-28-the-invariant-en      --relation=translate >/dev/null
"$bb" add src/posts/fr/29-la-langue-du-transit.fr.scm fr --derived-from=post-29-the-language-en      --relation=translate >/dev/null
"$bb" add src/posts/fr/30-le-premier-commit.fr.scm   fr --derived-from=post-30-the-first-commit-en   --relation=translate >/dev/null
done_round
"$bb" add src/posts/es/01-la-bodega.es.scm           es --derived-from=post-01-the-hold-en     --relation=translate >/dev/null
"$bb" add src/posts/es/02-el-hacedor.es.scm          es --derived-from=post-02-the-hacker-en   --relation=translate >/dev/null
"$bb" add src/posts/es/03-la-poliglota.es.scm        es --derived-from=post-03-the-polyglot-en --relation=translate >/dev/null
"$bb" add src/posts/es/04-el-veterano.es.scm         es --derived-from=post-04-the-senior-en   --relation=translate >/dev/null
"$bb" add src/posts/es/05-la-chica.es.scm            es --derived-from=post-05-the-kid-en      --relation=translate >/dev/null
done_round
"$bb" add src/posts/es/06-el-teorico.es.scm          es --derived-from=post-06-the-theorist-en    --relation=translate >/dev/null
"$bb" add src/posts/es/07-la-coordinadora.es.scm     es --derived-from=post-07-the-coordinator-en --relation=translate >/dev/null
"$bb" add src/posts/es/08-el-pensador.es.scm         es --derived-from=post-08-the-thinker-en     --relation=translate >/dev/null
"$bb" add src/posts/es/09-el-ciclo-aire.es.scm       es --derived-from=post-09-the-air-cycle-en   --relation=translate >/dev/null
"$bb" add src/posts/es/10-la-verificacion.es.scm     es --derived-from=post-10-the-check-en       --relation=translate >/dev/null
done_round
"$bb" add src/posts/es/11-la-partida.es.scm          es --derived-from=post-11-departure-en        --relation=translate >/dev/null
"$bb" add src/posts/es/12-el-corsario.es.scm         es --derived-from=post-12-the-privateer-en    --relation=translate >/dev/null
"$bb" add src/posts/es/13-el-ciudadano.es.scm        es --derived-from=post-13-the-citizen-en      --relation=translate >/dev/null
"$bb" add src/posts/es/14-la-educadora.es.scm        es --derived-from=post-14-the-educator-en     --relation=translate >/dev/null
"$bb" add src/posts/es/15-la-conectora.es.scm        es --derived-from=post-15-the-connector-en    --relation=translate >/dev/null
done_round
"$bb" add src/posts/es/16-la-ia-simbiotica.es.scm    es --derived-from=post-16-the-symbiotic-en      --relation=translate >/dev/null
"$bb" add src/posts/es/17-el-rezago-ancla.es.scm     es --derived-from=post-17-the-anchor-backlog-en --relation=translate >/dev/null
"$bb" add src/posts/es/18-la-cascada.es.scm          es --derived-from=post-18-the-refactor-en       --relation=translate >/dev/null
"$bb" add src/posts/es/19-el-borrado.es.scm          es --derived-from=post-19-the-memory-wipe-en    --relation=translate >/dev/null
"$bb" add src/posts/es/20-la-artista.es.scm          es --derived-from=post-20-the-artist-en         --relation=translate >/dev/null
done_round
"$bb" add src/posts/es/21-el-silencio.es.scm         es --derived-from=post-21-the-silence-en        --relation=translate >/dev/null
"$bb" add src/posts/es/22-la-despojada.es.scm        es --derived-from=post-22-the-stolen-en         --relation=translate >/dev/null
"$bb" add src/posts/es/23-el-investigador.es.scm     es --derived-from=post-23-the-researcher-en     --relation=translate >/dev/null
"$bb" add src/posts/es/24-la-gestora.es.scm          es --derived-from=post-24-the-steward-en        --relation=translate >/dev/null
"$bb" add src/posts/es/25-la-investigadora.es.scm    es --derived-from=post-25-the-academic-en       --relation=translate >/dev/null
done_round
"$bb" add src/posts/es/26-el-representante.es.scm    es --derived-from=post-26-the-representative-en --relation=translate >/dev/null
"$bb" add src/posts/es/27-el-manifiesto.es.scm       es --derived-from=post-27-the-manifesto-en      --relation=translate >/dev/null
"$bb" add src/posts/es/28-el-invariante.es.scm       es --derived-from=post-28-the-invariant-en      --relation=translate >/dev/null
"$bb" add src/posts/es/29-la-lengua-del-transito.es.scm es --derived-from=post-29-the-language-en    --relation=translate >/dev/null
"$bb" add src/posts/es/30-el-primer-commit.es.scm    es --derived-from=post-30-the-first-commit-en   --relation=translate >/dev/null
done_round

echo ">> manifests + generator"
add src/manifest-en.scm
add src/manifest-fr.scm
add src/manifest-es.scm
done_round
add src/manifest.scm
done_round
add src/generate-posts.scm
done_round
add src/generate-index.scm
done_round
add src/generate.en.scm en
add src/generate.fr.scm fr
add src/generate.es.scm es
done_round

echo "OK"
