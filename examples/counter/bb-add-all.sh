#!/bin/sh
# Initialize the counter store and register all combiners.
# Run from examples/counter/.
set -eu
bb=./bb

echo ">> initializing store"
"$bb" store init

echo ">> adding combiners"
"$bb" add src/clicker-state.en.scm
"$bb" add src/clicker.en.scm
"$bb" commit --all

echo ">> publishing"
"$bb" remote add self "file://$(pwd)" 2>/dev/null || true
"$bb" remote publish self clicker-state
"$bb" remote publish self clicker

echo ""
echo "Done. Start the server with:"
echo "  ./bb serve clicker-state clicker --port 8080"
echo "Then visit: http://localhost:8080/"
