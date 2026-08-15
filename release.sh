#!/bin/sh
# Build a relocatable bb release tarball: the bb binary plus every shared
# object it dlopens at runtime, resolved via $ORIGIN, so the extracted
# directory works on a host with nothing installed beyond glibc.
#
# Exact dlopen soname strings bb requires, confirmed by grepping
# src/transparenturing.scm (bb's own vendored liburing/tls FFI bindings —
# NOT letloop's lazy multi-candidate (letloop cffi) loader; these are
# loaded eagerly and unconditionally at library-instantiation time, so
# every bb command needs both, not just `bb serve`/https) and by running
# `strace -f -e trace=openat ./a.out eval '(+ 1 2)'`:
#   - "liburing-ffi.so.2"  (src/transparenturing.scm:815)
#   - "libtls.so"          (src/transparenturing.scm:2835)
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LETLOOP="$ROOT/submodules/letloop"
PREFIX="$LETLOOP/local"

VERSION=${VERSION:-$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo dev)}
ARCH=${ARCH:-$(uname -m)}
STAGE="$ROOT/dist/bb-$VERSION-$ARCH-linux"
TARBALL="$ROOT/bb-$VERSION-$ARCH-linux.tar.gz"
EXAMPLE="$ROOT/examples/counter/src/clicker-state.en.scm"
EXAMPLE_HASH=8783a09eceee680d759f361a79aa151564d50505c57d4eea7f67f1455ad7a446
DLOPEN_NAMES="liburing-ffi.so.2 libtls.so"

log() { printf '==> %s\n' "$1"; }
die() { printf 'release.sh: %s\n' "$1" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

need patchelf; need ldconfig; need dpkg; need sha256sum; need git; need tar; need od; need awk

log "building chez/letloop toolchain and FFI dependencies (skip steps already done)"
# `make chezscheme` is not idempotent — it unconditionally `rm -rf`s and
# rebuilds from source (~5-15 min) — so guard it ourselves the way the
# other targets here already guard themselves (see e.g. `liburing:` in
# submodules/letloop/makefile, which skips if its output already exists).
[ -x "$PREFIX/bin/scheme" ] || make -C "$LETLOOP" chezscheme SCHEME="$(command -v scheme)"
make -C "$LETLOOP" letloop SCHEME="$PREFIX/bin/scheme"
make -C "$LETLOOP" dependencies

log "compiling bb"
( cd "$ROOT" && LD_LIBRARY_PATH="$PREFIX/lib" "$PREFIX/bin/letloop" compile \
    --visible-libraries src/ src/bb/cli.scm main )
[ -x "$ROOT/a.out" ] || die "build did not produce ./a.out"

log "staging $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE"
MANIFEST="$STAGE/MANIFEST.txt"
: > "$MANIFEST"

record() {  # record SONAME PROVENANCE
  h=$(sha256sum "$STAGE/$1" | cut -d' ' -f1)
  printf '%-28s %s  %s\n' "$1" "$h" "$2" >> "$MANIFEST"
}

set_rpath() {
  patchelf --set-rpath '$ORIGIN' "$1" 2>/dev/null \
    || patchelf --force-rpath --set-rpath '$ORIGIN' "$1"
}

# bb is not a plain ELF: `letloop compile` appends the boot image after
# the host, as [boot][8-byte LE length]["LETLOOP\1"], read back from EOF
# via /proc/self/exe (see submodules/letloop/CLAUDE.md). patchelf knows
# nothing about that trailer and silently drops it when it rewrites the
# file — the result still runs `--print-soname` fine but fails at
# startup with "cannot find compatible bb.boot in search path" (verified
# empirically: the trailer bytes come back as zeros after a plain
# `patchelf --set-rpath`). So: strip the trailer, patch the bare host,
# re-append the trailer — the same strip/append `letloop compile` itself
# already does to assemble a.out in the first place.
set_rpath_bb() {
  bb="$1"
  size=$(wc -c < "$bb")
  magic=$(tail -c 8 "$bb" | od -An -tx1 | tr -d ' \n')
  if [ "$size" -ge 16 ] && [ "$magic" = "4c45544c4f4f5001" ]; then
    bootlen=$(od -An -tu1 -j $((size - 16)) -N 8 "$bb" \
      | tr -s ' ' '\n' | grep -v '^$' \
      | awk '{v += $1 * (2 ^ ((NR - 1) * 8))} END {printf "%.0f", v}')
    tsize=$((bootlen + 16))
    hsize=$((size - tsize))
    host="$bb.host.tmp"
    head -c "$hsize" "$bb" > "$host"
    chmod 755 "$host"
    set_rpath "$host"
    tail -c "$tsize" "$bb" >> "$host"
    mv "$host" "$bb"
  else
    set_rpath "$bb"
  fi
}

# Copy SRC's real file into $STAGE under its own SONAME, patch its rpath,
# record it, and recurse into its non-glibc dependency closure (ldd).
vendor_file() {
  src="$1"
  soname=$(patchelf --print-soname "$src" 2>/dev/null || basename "$src")
  dest="$STAGE/$soname"
  [ -e "$dest" ] && return 0
  cp -L "$src" "$dest"
  set_rpath "$dest"
  pkg=$(dpkg -S "$(realpath "$src")" 2>/dev/null | cut -d: -f1)
  record "$soname" "${pkg:-unknown package}"
  ldd "$src" 2>/dev/null | grep '=>' | while read -r depname _ deppath _; do
    case "$depname" in
      linux-vdso.so*|libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|ld-linux*) continue ;;
    esac
    [ -n "$deppath" ] && [ -e "$deppath" ] && vendor_file "$(realpath "$deppath")"
  done
}

# Resolve NAME (an exact dlopen() string) via the loader's own cache,
# vendor its real file, and symlink NAME to it if they differ (a bare
# "libtls.so" only exists in -dev packages; user hosts won't have it).
vendor_dlopen_name() {
  name="$1"
  src=$(ldconfig -p | awk -v n="$name" '$1==n{print $NF; exit}')
  [ -n "$src" ] || die "cannot resolve $name via ldconfig -p — is it installed on this build host?"
  src=$(realpath "$src")
  vendor_file "$src"
  soname=$(patchelf --print-soname "$src" 2>/dev/null || basename "$src")
  [ "$name" = "$soname" ] || ln -sf "$soname" "$STAGE/$name"
}

for name in $DLOPEN_NAMES; do vendor_dlopen_name "$name"; done

# liburing-ffi.so.2 above came from the system ldconfig cache; if it was
# actually built from source into $PREFIX (the "dependencies" target
# above), prefer that copy and record git provenance instead of a deb.
if [ -e "$PREFIX/lib/liburing-ffi.so.2" ]; then
  URING_REAL=$(realpath "$PREFIX/lib/liburing-ffi.so.2")
  cp -L "$URING_REAL" "$STAGE/liburing-ffi.so.2"
  set_rpath "$STAGE/liburing-ffi.so.2"
  URING_REV=$(git -C "$PREFIX/src/liburing" rev-parse HEAD 2>/dev/null || echo unknown)
  sed -i '\|^liburing-ffi\.so\.2 |d' "$MANIFEST"
  record liburing-ffi.so.2 "https://github.com/axboe/liburing @ $URING_REV"
fi

cp "$ROOT/a.out" "$STAGE/bb"
set_rpath_bb "$STAGE/bb"
record bb "built from $(git -C "$ROOT" rev-parse HEAD)"

log "smoke test: patched bb output must match the unpatched build byte-for-byte"
probe() {  # probe BB-PATH LD-LIBRARY-PATH
  bb="$1"; ldlp="$2"
  dir="$ROOT/dist/.smoketest"
  rm -rf "$dir"; mkdir -p "$dir"
  ( cd "$dir" \
    && LD_LIBRARY_PATH="$ldlp" "$bb" --help \
    && LD_LIBRARY_PATH="$ldlp" "$bb" store init \
    && LD_LIBRARY_PATH="$ldlp" "$bb" add "$EXAMPLE" )
  rm -rf "$dir"
}
BEFORE=$(probe "$ROOT/a.out" "$PREFIX/lib")
AFTER=$(probe "$STAGE/bb" "")
[ "$BEFORE" = "$AFTER" ] || die "smoke test: patched bb output differs from the unpatched build"
printf '%s\n' "$AFTER" | grep -q "$EXAMPLE_HASH" || die "smoke test: unexpected combiner hash"

log "packaging $TARBALL"
( cd "$ROOT/dist" && tar czf "$TARBALL" "$(basename "$STAGE")" )
sha256sum "$TARBALL" > "$TARBALL.sha256"
log "done: $TARBALL"
