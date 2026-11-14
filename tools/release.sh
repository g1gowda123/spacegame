#!/usr/bin/env bash
# One-command Web release for Orbit & Outplay.
#
#   tools/release.sh                 # import -> export -> package -> hash -> smoke serve -> build/RELEASE.txt
#   tools/release.sh --skip-export   # re-package the existing build/web (no Godot needed)
#   tools/release.sh --no-serve      # skip the HTTP smoke test
#   tools/release.sh --strict        # fail if submission/ assets are older than the PCK
#
# This is the canonical release entry point on the Linux release box.
# tools/release.py is the Windows twin and runs the same steps in the same
# order, so either one produces the same nine files, the same ZIP layout and
# the same RELEASE.txt fields.
#
# Design rule (C2 on docs/BOARD.md): a release must never depend on anyone's
# memory. Every step is deterministic, every artifact is hashed and stamped in
# build/RELEASE.txt, and a failed run cannot leave an old ZIP looking fresh:
# the ZIP is deleted BEFORE the export and only re-created after it succeeds.
#
# Exit codes: 0 ok, 1 bad usage/preflight, 2 export failed, 3 artifacts missing,
#             4 packaging failed, 5 smoke serve failed, 6 stale assets (--strict).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PRESET="Web"
BUILD_DIR="build/web"
LOG_DIR="build/logs"
ZIP_PATH="submission/orbit_outplay_web.zip"
RELEASE_TXT="build/RELEASE.txt"
REQUIRED=(index.html index.js index.wasm index.pck)
GODOT="${GODOT:-godot}"
PORT="${PORT:-8060}"
DO_EXPORT=1
DO_SERVE=1
DO_SMOKE=1
STRICT=0

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Environment:
  GODOT=/path/to/godot   Godot 4.7.2 binary (default: godot on PATH)
  PORT=8060              port for the HTTP smoke test
  PYTHON=python3         interpreter for packaging (python3, then python)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --skip-export) DO_EXPORT=0 ;;
    --no-serve) DO_SERVE=0 ;;
    --no-smoke) DO_SMOKE=0 ;;
    --strict) STRICT=1 ;;
    --port) shift; PORT="${1:?--port needs a value}" ;;
    --godot) shift; GODOT="${1:?--godot needs a path}" ;;
    *) echo "release: unknown option '$1' (try --help)" >&2; exit 1 ;;
  esac
  shift
done

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s ==\n' "$*"; }
die()  { printf 'release: %s\n' "$*" >&2; exit "${2:-1}"; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing '$1' on PATH" 1; }
bytes() { wc -c < "$1" | tr -d ' '; }
sha() { sha256sum "$1" | awk '{print $1}'; }

need sha256sum
need curl

# python3 first (Linux release box), then python (Windows Git Bash, where the
# python3 App Execution Alias exists but is not a working interpreter).
PY=""
for cand in "${PYTHON:-}" python3 python; do
  [[ -n "$cand" ]] || continue
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import sys,zipfile' >/dev/null 2>&1; then
    PY="$cand"; break
  fi
done
[[ -n "$PY" ]] || die "no working python (set PYTHON=...)" 1

STAMP="$(date -Is)"
STAMP_FILE="$(date +%Y%m%d-%H%M%S)"
GIT_HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo 'no-git')"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
GIT_DIRTY="clean"
[[ -n "$(git status --porcelain -uno 2>/dev/null || true)" ]] && GIT_DIRTY="dirty (uncommitted tracked changes)"

mkdir -p "$LOG_DIR" submission

if (( DO_EXPORT )); then
  command -v "$GODOT" >/dev/null 2>&1 || die "Godot not found ('$GODOT'); pass --godot or set GODOT, or use --skip-export" 1
  GODOT_VERSION="$("$GODOT" --version 2>/dev/null | head -n1 || echo unknown)"
else
  GODOT_VERSION="(not run)"
fi

# A stale ZIP or a stale stamp is worse than none: remove both before anything
# can fail, so a failed run cannot leave an old "RELEASE OK" next to no ZIP.
rm -f "$ZIP_PATH" "$RELEASE_TXT"

step "preflight"
say "repo        $ROOT"
say "git         $GIT_HEAD ($GIT_BRANCH, $GIT_DIRTY)"
say "godot       $GODOT_VERSION"
say "python      $PY ($("$PY" --version 2>&1))"
say "stamp       $STAMP"
say "zip         $ZIP_PATH (cleared)"
say "stamp file  $RELEASE_TXT (cleared)"

# Godot only imports art when an editor pass touches it. A fresh clone (or any
# tree where art arrived from someone else's machine) has the PNGs but no
# .godot/imported cache, and the export then ships a PCK with no textures: the
# sector tileset dies at runtime on
#   Failed loading resource: res://.godot/imported/ice_flat_a.png-*.ctex
# so import before every export. build/.gdignore keeps Godot from scanning the
# exports and re-importing them as project art.
mkdir -p build
[[ -f build/.gdignore ]] || : > build/.gdignore

if (( DO_EXPORT )); then
  step "import"
  IMPORT_LOG="$LOG_DIR/import-$STAMP_FILE.log"
  set +e
  "$GODOT" --headless --path . --import >"$IMPORT_LOG" 2>&1
  IMPORT_RC=$?
  set -e
  say "import exit $IMPORT_RC (log: $IMPORT_LOG)"
  (( IMPORT_RC == 0 )) || die "import failed with exit $IMPORT_RC" 2

  step "export ($PRESET)"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"   # Godot 4.7 does not create the target folder itself
  EXPORT_LOG="$LOG_DIR/export-$STAMP_FILE.log"
  set +e
  "$GODOT" --headless --export-release "$PRESET" "$BUILD_DIR/index.html" 2>&1 | tee "$EXPORT_LOG"
  EXPORT_RC="${PIPESTATUS[0]}"
  set -e
  say "export exit $EXPORT_RC (log: $EXPORT_LOG)"
  (( EXPORT_RC == 0 )) || die "export failed with exit $EXPORT_RC" 2
  # Godot can still drop import sidecars next to the exported PNGs; they must
  # never reach the ZIP.
  find "$BUILD_DIR" -maxdepth 1 -name '*.import' -delete 2>/dev/null || true
else
  step "export skipped (--skip-export)"
fi

step "artifacts"
MISSING=0
for f in "${REQUIRED[@]}"; do
  if [[ -f "$BUILD_DIR/$f" ]]; then
    say "  ok      $(printf '%-14s' "$f") $(bytes "$BUILD_DIR/$f") B  $(date -r "$BUILD_DIR/$f" -Is 2>/dev/null || true)"
  else
    say "  MISSING $f"; MISSING=1
  fi
done
(( MISSING == 0 )) || die "$BUILD_DIR is incomplete; refusing to package" 3

if (( DO_SMOKE )) && (( DO_EXPORT )); then
  step "headless boot smoke (--quit-after 8)"
  SMOKE_LOG="$LOG_DIR/headless-$STAMP_FILE.log"
  set +e
  timeout 60 "$GODOT" --headless --path . --quit-after 8 >"$SMOKE_LOG" 2>&1
  SMOKE_RC=$?
  set -e
  BAD="$(grep -E 'SCRIPT ERROR|Parse Error|Failed to load' "$SMOKE_LOG" || true)"
  if [[ -n "$BAD" ]]; then
    say "$BAD"
    die "headless boot reported errors (log: $SMOKE_LOG)" 2
  fi
  say "headless exit $SMOKE_RC, 0 SCRIPT ERROR / Parse Error / Failed to load (log: $SMOKE_LOG)"
else
  step "headless smoke skipped"
fi

step "package"
if ! "$PY" - "$BUILD_DIR" "$ZIP_PATH" <<'PY'
import os, sys, zipfile

src, out = sys.argv[1], sys.argv[2]
files = []
for name in sorted(os.listdir(src)):
    if name.startswith('.') or name.endswith('.import'):
        continue
    path = os.path.join(src, name)
    if not os.path.isfile(path):
        continue
    files.append(name)

with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for name in files:
        zf.write(os.path.join(src, name), arcname=name)
print(f"  {out}: {len(files)} entries")
for name in files:
    print(f"    {name:32s} {os.path.getsize(os.path.join(src, name)):>12,} B")
PY
then
  die "packaging failed" 4
fi
[[ -s "$ZIP_PATH" ]] || die "zip was not written" 4
ZIP_BYTES="$(bytes "$ZIP_PATH")"
ZIP_SHA="$(sha "$ZIP_PATH")"
ZIP_ENTRIES="$("$PY" -c 'import sys,zipfile; print(len(zipfile.ZipFile(sys.argv[1]).namelist()))' "$ZIP_PATH")"

step "hashes"
PCK="$BUILD_DIR/index.pck"
PCK_BYTES="$(bytes "$PCK")"; PCK_SHA="$(sha "$PCK")"
WASM_BYTES="$(bytes "$BUILD_DIR/index.wasm")"; WASM_SHA="$(sha "$BUILD_DIR/index.wasm")"
HTML_BYTES="$(bytes "$BUILD_DIR/index.html")"; HTML_SHA="$(sha "$BUILD_DIR/index.html")"
say "pck   $PCK_BYTES B  sha256 $PCK_SHA"
say "wasm  $WASM_BYTES B  sha256 $WASM_SHA"
say "html  $HTML_BYTES B  sha256 $HTML_SHA"
say "zip   $ZIP_BYTES B  sha256 $ZIP_SHA  ($ZIP_ENTRIES entries)"

SERVE_LINE="not run"
if (( DO_SERVE )); then
  step "smoke serve (127.0.0.1:$PORT)"
  "$PY" -m http.server "$PORT" --bind 127.0.0.1 --directory "$BUILD_DIR" >"$LOG_DIR/serve-$STAMP_FILE.log" 2>&1 &
  SRV_PID=$!
  trap 'kill "$SRV_PID" 2>/dev/null || true' EXIT
  ready=0
  for _ in $(seq 1 40); do
    if curl -fsS --max-time 2 -o /dev/null "http://127.0.0.1:$PORT/index.html" 2>/dev/null; then ready=1; break; fi
    sleep 0.25
  done
  (( ready == 1 )) || die "server never answered on port $PORT (log: $LOG_DIR/serve-$STAMP_FILE.log)" 5
  FAIL=0
  SERVE_LINE=""
  for f in index.html index.wasm index.pck; do
    code="$(curl -sS -o /dev/null --max-time 30 -w '%{http_code}' "http://127.0.0.1:$PORT/$f" || echo 000)"
    say "  $f -> $code"
    SERVE_LINE+="$f $code  "
    [[ "$code" == "200" ]] || FAIL=1
  done
  kill "$SRV_PID" 2>/dev/null || true
  trap - EXIT
  (( FAIL == 0 )) || die "one or more assets did not serve 200" 5
fi

step "asset stamp audit"
STALE=0
PCK_MTIME="$(date -r "$PCK" +%s)"
AUDIT=""
shopt -s nullglob
for f in submission/* demo/*; do
  [[ -f "$f" ]] || continue
  [[ "$f" == "$ZIP_PATH" ]] && continue
  mt="$(date -r "$f" +%s)"
  when="$(date -r "$f" -Is)"
  if (( mt < PCK_MTIME )); then
    say "  STALE  $f  $when  (older than the PCK)"
    AUDIT+="STALE $f $when"$'\n'
    STALE=1
  else
    say "  ok     $f  $when"
    AUDIT+="ok $f $when"$'\n'
  fi
done
shopt -u nullglob
say "  zip    $ZIP_PATH  $(date -r "$ZIP_PATH" -Is)  (just built)"
if (( STALE )) && (( STRICT )); then
  say "  --strict: submission/ assets predate this build; re-render deck/video before shipping"
fi

step "release stamp"
{
  echo "ORBIT & OUTPLAY - release stamp"
  echo "generated     $STAMP"
  echo "git           $GIT_HEAD ($GIT_BRANCH, $GIT_DIRTY)"
  echo "godot         $GODOT_VERSION"
  echo
  echo "pck           $PCK_BYTES B  sha256 $PCK_SHA"
  echo "wasm          $WASM_BYTES B  sha256 $WASM_SHA"
  echo "html          $HTML_BYTES B  sha256 $HTML_SHA"
  echo "zip           $ZIP_BYTES B  sha256 $ZIP_SHA  entries $ZIP_ENTRIES"
  echo "zip path      $ZIP_PATH  ($(date -r "$ZIP_PATH" -Is))"
  echo "serve         $SERVE_LINE"
  echo
  echo "asset audit   (older than the PCK = re-render before shipping)"
  printf '%s' "$AUDIT" | sed 's/^/  /'
  echo "  current $ZIP_PATH $(date -r "$ZIP_PATH" -Is)"
  echo
  echo "gate line     RELEASE OK pck=${PCK_BYTES}B zip=${ZIP_BYTES}B $(date -r "$ZIP_PATH" +%H:%M) - build ready for QA"
} > "$RELEASE_TXT"
say "  wrote $RELEASE_TXT"
cat "$RELEASE_TXT" | sed 's/^/  | /'

say ""
say "RELEASE OK pck=${PCK_BYTES}B zip=${ZIP_BYTES}B $(date -r "$ZIP_PATH" +%H:%M) - build ready for QA"
if (( STALE )); then
  say "WARNING: $(printf '%s' "$AUDIT" | grep -c '^STALE') submission asset(s) older than this build"
  if (( STRICT )); then exit 6; fi
fi
exit 0
