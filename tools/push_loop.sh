#!/usr/bin/env bash
# ORION push loop: keeps the tree pushed while the team works.
# Docs conflicts are resolved by union (append-only logs); code conflicts abort
# the rebase and are left for a human/lead to resolve.
set -u
REPO="/home/g1/godot/nasa"
LOG="/tmp/opencode/push_loop.log"
INTERVAL="${1:-180}"
cd "$REPO" || exit 1
resolve_docs() {
  python3 - <<'PY'
import re, pathlib, glob
for f in glob.glob('docs/*.md'):
    p = pathlib.Path(f); s = p.read_text()
    if '<<<<<<<' in s:
        s = re.sub(r'<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n',
                   lambda m: m.group(1).rstrip('\n') + '\n' + m.group(2), s, flags=re.S)
        p.write_text(s); print('resolved', f)
PY
}
while true; do
  stamp=$(date +%H:%M:%S)
  # pull first so the loop never fights the other agents' pushes
  GIT_TERMINAL_PROMPT=0 git fetch -q >/dev/null 2>&1
  if ! git rebase -q origin/main >/dev/null 2>&1; then
    if grep -rlq "<<<<<<<" --include=*.gd --include=*.tscn --include=*.json . ; then
      git rebase --abort >/dev/null 2>&1
      echo "$stamp CODE CONFLICT on pull - aborted, needs lead" >> "$LOG"
    else
      resolve_docs >/dev/null 2>&1
      git add docs/ >/dev/null 2>&1
      git -c core.editor=true rebase --continue >/dev/null 2>&1 || true
    fi
  fi
  if [ -n "$(git status --porcelain)" ]; then
    git add -A >/dev/null 2>&1
    git commit -qm "checkpoint: auto $(date +%H:%M:%S)" >/dev/null 2>&1
  fi
  for attempt in 1 2 3; do
    GIT_TERMINAL_PROMPT=0 git push -q >/dev/null 2>&1 && break
    GIT_TERMINAL_PROMPT=0 git fetch -q >/dev/null 2>&1
    if ! git rebase -q origin/main >/dev/null 2>&1; then
      if grep -rlq "<<<<<<<" --include=*.gd --include=*.tscn --include=*.json . ; then
        git rebase --abort >/dev/null 2>&1
        echo "$stamp CODE CONFLICT - rebase aborted, needs lead" >> "$LOG"
        break
      fi
      resolve_docs >/dev/null 2>&1
      git add docs/ >/dev/null 2>&1
      git -c core.editor=true rebase --continue >/dev/null 2>&1 || true
    fi
  done
  head=$(git rev-parse --short HEAD 2>/dev/null)
  remote=$(git rev-parse --short origin/main 2>/dev/null)
  if [ "$head" = "$remote" ]; then echo "$stamp synced $head" >> "$LOG"; else echo "$stamp BEHIND head=$head origin=$remote" >> "$LOG"; fi
  sleep "$INTERVAL"
done
