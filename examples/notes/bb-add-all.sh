#!/bin/sh
# Initialize the notes store and register all combiners.
# Run from examples/notes/. Combiners must be added in dependency order.
set -eu
bb=./bb

echo ">> initializing store"
"$bb" store init

echo ">> adding combiners (dependency order)"
# markdown: escaping, then scanning helpers, then inline, then blocks
"$bb" add src/md-escape-chars.en.scm
"$bb" add src/md-escape.en.scm
"$bb" add src/md-index-of.en.scm
"$bb" add src/md-prefix.en.scm
"$bb" add src/md-split-lines.en.scm
"$bb" add src/md-next-marker.en.scm
"$bb" add src/md-find-pair.en.scm
"$bb" add src/md-inline-from.en.scm
"$bb" add src/md-inline.en.scm
"$bb" add src/md-inline-join.en.scm
"$bb" add src/md-ul-items.en.scm
"$bb" add src/md-reverse.en.scm
"$bb" add src/md-flush.en.scm
"$bb" add src/md-blocks.en.scm
"$bb" add src/md-render.en.scm
# form decoding
"$bb" add src/hex-digit.en.scm
"$bb" add src/form-decode-chars.en.scm
"$bb" add src/form-decode.en.scm
"$bb" add src/form-get-scan.en.scm
"$bb" add src/form-get.en.scm
# notes model and UI
"$bb" add src/notes-name-ok.en.scm
"$bb" add src/notes-count-folder.en.scm
"$bb" add src/notes-render-folders.en.scm
"$bb" add src/notes-render-notes.en.scm
"$bb" add src/notes-folder-options.en.scm
"$bb" add src/notes-page.en.scm
"$bb" add src/notes-editor.en.scm
# the application itself
"$bb" add src/notes-state.en.scm
"$bb" add src/notes.en.scm
"$bb" commit --all

echo ">> publishing"
"$bb" remote add self "file://$(pwd)" 2>/dev/null || true
"$bb" remote publish self notes-state
"$bb" remote publish self notes

echo ""
echo "Done. Start the server with:"
echo "  ./bb serve notes-state notes --port 8080"
echo "Then visit: http://localhost:8080/"
