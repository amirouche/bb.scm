#!/bin/sh
# Build the todomvc store. Run from examples/todomvc/.
# Combiners must be added in dependency order.
set -eu
bb=./bb

echo ">> initializing store"
"$bb" store init

echo ">> adding combiners (dependency order)"
# leaf combiners — no store deps
"$bb" add src/todos-state.en.scm
"$bb" add src/todos-count-active.en.scm
"$bb" add src/todos-remove-completed.en.scm
"$bb" add src/todos-render-item.en.scm
"$bb" add src/todos-toggle.en.scm
"$bb" add src/todos-delete.en.scm
# todos-render-list depends on todos-render-item
"$bb" add src/todos-render-list.en.scm
# todos depends on all of the above
"$bb" add src/todos.en.scm
"$bb" commit --all

echo ">> publishing"
"$bb" remote add self "file://$(pwd)" 2>/dev/null || true
"$bb" remote publish self todos-state
"$bb" remote publish self todos

echo ""
echo "Done. Start the server with:"
echo "  ./bb serve todos-state todos --port 8080"
echo "Then visit: http://localhost:8080/"
echo ""
echo "Navigate the combiner graph:"
echo "  ./bb tree todos          # see all combiner deps"
echo "  ./bb caller todos-render-item   # what calls render-item"
