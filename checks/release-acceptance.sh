#!/usr/bin/env bash
# Step-3 acceptance test for a release tarball (see release.sh): extract
# it to an arbitrary path and run bb from inside a sandbox where the
# system's own copies of the dlopen'd libs are hidden, so only the
# tarball's vendored copies (found via bb's $ORIGIN rpath) can possibly
# satisfy them.
#
# Uses bwrap directly rather than `letloop root` (which additionally
# unshares pid and mounts a fresh /proc): that combination is blocked by
# seccomp in some nested-container CI/dev sandboxes ("Can't mount proc on
# /newroot/proc: Operation not permitted"), and isn't needed here — this
# test only needs filesystem-visibility isolation, not process isolation.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARBALL=${1:-$(ls -t "$ROOT"/bb-*-linux.tar.gz 2>/dev/null | head -1)}
[ -n "${TARBALL:-}" ] && [ -e "$TARBALL" ] || { echo "usage: $0 <tarball.tar.gz>" >&2; exit 1; }
command -v bwrap >/dev/null 2>&1 || { echo "release-acceptance.sh: bwrap not found" >&2; exit 1; }

EXTRACT=$(mktemp -d /tmp/bb-accept-XXXXXX)
cleanup() {
  # bwrap (without --unshare-pid, deliberately — see run_in_sandbox)
  # doesn't reap a backgrounded sandboxed child on its own, so make sure
  # no stray `bb serve` survives this script even on an early exit.
  pkill -f "$EXTRACT/.*bb serve" 2>/dev/null || true
  rm -rf "$EXTRACT"
}
trap cleanup EXIT
tar xzf "$TARBALL" -C "$EXTRACT"
BB_DIR=$(find "$EXTRACT" -mindepth 1 -maxdepth 1 -type d -name 'bb-*')
echo "==> extracted to $BB_DIR"

# Every soname bb's transparenturing.scm dlopens or transitively needs
# (see release.sh) — hide every host copy of each so the sandbox has
# neither liburing nor libtls installed, exactly like a clean host.
MASKED_PATTERNS=(liburing-ffi.so.2 'libtls.so*' libssl.so.3 libcrypto.so.3 libz.so.1 libzstd.so.1)
mask_args=()
for pattern in "${MASKED_PATTERNS[@]}"; do
  while IFS= read -r f; do
    mask_args+=(--bind /dev/null "$f")
  done < <(find /usr/lib /lib -xdev -name "$pattern" 2>/dev/null)
done
echo "==> masking ${#mask_args[@]} host library path(s)"

run_in_sandbox() {
  local workdir="$1"; shift
  bwrap --die-with-parent --ro-bind / / "${mask_args[@]}" \
    --bind "$EXTRACT" "$EXTRACT" \
    --bind "$workdir" "$workdir" \
    --dev /dev \
    --chdir "$workdir" \
    -- "$@"
}

fail=0

echo "==> bb --help"
run_in_sandbox "$BB_DIR" "$BB_DIR/bb" --help >/dev/null

echo "==> bb add examples/counter/... (no system liburing/libtls — vendored copies only)"
STORE=$(mktemp -d)
run_in_sandbox "$STORE" "$BB_DIR/bb" store init >/dev/null
run_in_sandbox "$STORE" "$BB_DIR/bb" add "$ROOT/examples/counter/src/clicker-state.en.scm"
rm -rf "$STORE"

echo "==> ldd: every tarball file must resolve to the tarball or glibc only"
for f in "$BB_DIR"/*; do
  [ -f "$f" ] || continue
  bad=$(ldd "$f" 2>/dev/null | grep -v "$BB_DIR" \
    | grep -viE 'linux-vdso|libc\.so|libm\.so|libpthread|libdl\.so|librt\.so|ld-linux|statically linked' || true)
  if [ -n "$bad" ]; then
    echo "  FAIL: $(basename "$f") resolves outside the tarball:"
    echo "$bad" | sed 's/^/    /'
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "  OK"

echo "==> bb serve todos-state todos (loading vendored liburing-ffi)"
TODO_DIR=$(mktemp -d)
cp -r "$ROOT/examples/todomvc/." "$TODO_DIR/"
run_in_sandbox "$TODO_DIR" "$BB_DIR/bb" store init >/dev/null
for c in todos-state todos-count-active todos-remove-completed todos-render-item \
         todos-toggle todos-delete todos-render-list todos; do
  run_in_sandbox "$TODO_DIR" "$BB_DIR/bb" add "src/$c.en.scm" >/dev/null
done
run_in_sandbox "$TODO_DIR" "$BB_DIR/bb" commit --all >/dev/null
run_in_sandbox "$TODO_DIR" "$BB_DIR/bb" remote add self "file://$TODO_DIR" >/dev/null 2>&1 || true
run_in_sandbox "$TODO_DIR" "$BB_DIR/bb" remote publish self todos-state >/dev/null
run_in_sandbox "$TODO_DIR" "$BB_DIR/bb" remote publish self todos >/dev/null
SERVE_LOG=$(mktemp)
run_in_sandbox "$TODO_DIR" "$BB_DIR/bb" serve todos-state todos --port 18080 >"$SERVE_LOG" 2>&1 &
SERVER_PID=$!
sleep 1
if kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "  OK: bb serve started (pid $SERVER_PID) and is still running"
  pkill -f "$EXTRACT/.*bb serve" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
else
  echo "  FAIL: bb serve exited immediately"
  cat "$SERVE_LOG"
  fail=1
fi
rm -rf "$TODO_DIR" "$SERVE_LOG"

echo "==> https"
echo "  NOTE: libtls.so is dlopen'd eagerly, unconditionally, at process startup"
echo "  (src/transparenturing.scm:2835) for every bb command — not lazily on first"
echo "  https use. Every check above already proves the vendored libtls.so loads;"
echo "  bb's CLI has no standalone https-client command to additionally exercise a"
echo "  live TLS handshake against."

echo "==> remove one vendored lib at a time — what breaks"
printf '%-24s %-10s %s\n' "removed lib" "bb --help" "bb add"
for f in "$BB_DIR"/*.so*; do
  [ -f "$f" ] || [ -L "$f" ] || continue
  name=$(basename "$f")
  hidden="$f.hidden"
  mv "$f" "$hidden"
  h_ok=PASS
  run_in_sandbox "$BB_DIR" "$BB_DIR/bb" --help >/dev/null 2>&1 || h_ok=FAIL
  a_ok=PASS
  S=$(mktemp -d)
  run_in_sandbox "$S" "$BB_DIR/bb" store init >/dev/null 2>&1 || true
  run_in_sandbox "$S" "$BB_DIR/bb" add "$ROOT/examples/counter/src/clicker-state.en.scm" >/dev/null 2>&1 || a_ok=FAIL
  rm -rf "$S"
  mv "$hidden" "$f"
  printf '%-24s %-10s %s\n' "$name" "$h_ok" "$a_ok"
done

if [ "$fail" -ne 0 ]; then
  echo "ACCEPTANCE TEST FAILED"
  exit 1
fi
echo "ACCEPTANCE TEST PASSED"
