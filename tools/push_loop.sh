#!/usr/bin/env bash
# ORION push loop: keeps the tree pushed while the team works.
#
# Rules it enforces:
#   * pull (rebase) before every push, so two agents can never wedge each other
#   * docs/*.md conflicts are union-merged (they are append-only logs)
#   * code conflicts abort the rebase and are logged for the lead
#   * any staged file over 50 MB is refused and reported (GitHub rejects >100 MB
#     and a single such file makes every push time out)
#   * every git network call has a timeout so the loop cannot hang
set -u
REPO="/home/g1/godot/nasa"
LOG="/tmp/opencode/push_loop.log"
INTERVAL="${1:-150}"
MAX_MB="${MAX_MB:-50}"
cd "$REPO" || exit 1

log() { echo "$(date +%H:%M:%S) $*" >> "$LOG"; }

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

big_staged() {
  # returns staged paths bigger than MAX_MB
  git diff --cached --name-only -z | while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
    [ "$sz" -gt $((MAX_MB * 1024 * 1024)) ] && echo "$f $(($sz / 1048576))MB"
  done
}

recover_rebase() {
  if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
    if grep -rlq "<<<<<<<" --include=*.gd --include=*.tscn --include=*.json --include=*.godot . 2>/dev/null; then
      git rebase --abort >/dev/null 2>&1
      log "CODE CONFLICT - rebase aborted, needs lead"
    else
      resolve_docs >/dev/null 2>&1
      git add docs/ >/dev/null 2>&1
      git -c core.editor=true rebase --continue >/dev/null 2>&1 || git rebase --abort >/dev/null 2>&1
    fi
  fi
}

while true; do
  recover_rebase
  started=$(date +%s)

  # 1. pull first
  timeout 60 git fetch -q >/dev/null 2>&1
  if ! timeout 120 git rebase -q origin/main >/dev/null 2>&1; then
    recover_rebase
  fi

  # 2. stage whatever the team left in the tree
  if [ -n "$(git status --porcelain)" ]; then
    git add -A >/dev/null 2>&1
    blocked=$(big_staged)
    if [ -n "$blocked" ]; then
      log "REFUSED large staged file(s): $blocked"
      git reset -q
    else
      git commit -qm "checkpoint: auto $(date +%H:%M:%S)" >/dev/null 2>&1
    fi
  fi

  # 3. push, rebasing once more if the remote moved
  for attempt in 1 2 3; do
    if timeout 180 git push -q >/dev/null 2>&1; then break; fi
    timeout 60 git fetch -q >/dev/null 2>&1
    if ! timeout 120 git rebase -q origin/main >/dev/null 2>&1; then
      recover_rebase
      continue
    fi
  done

  sha=$(git rev-parse --short HEAD 2>/dev/null)
  behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
  if [ "${behind:-0}" -eq 0 ]; then
    log "synced $sha ($(($(date +%s) - started))s)"
  else
    log "BEHIND by $behind after push attempts - needs lead: $sha"
  fi

  sleep "$INTERVAL"
done
