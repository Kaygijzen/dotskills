#!/usr/bin/env bash
# Tests for statusline.sh: spend rate, ahead/behind upstream and worktree detection.
# Usage: statusline/test-statusline.sh

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/statusline.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK/tmp"  # isolates the git cache
mkdir -p "$TMPDIR"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
unset COLORTERM CLAUDE_STATUSLINE_ASCII CLAUDE_STATUSLINE_NERDFONT CLAUDE_STATUSLINE_POWERLINE

failed=0
check() {  # check <name> <haystack> <needle> [absent]
  if [[ "${4:-}" == absent ]]; then
    [[ "$2" != *"$3"* ]] && { echo "ok   $1"; return; }
  else
    [[ "$2" == *"$3"* ]] && { echo "ok   $1"; return; }
  fi
  echo "FAIL $1: expected ${4:+no }'$3' in: $2"; failed=1
}

run() {  # run <dir> <cost> <duration_ms> [context_window_size]
  jq -n --arg d "$1" --argjson c "$2" --argjson ms "$3" --argjson ctx "${4:-0}" \
    '{model: {display_name: "Test"}, workspace: {current_dir: $d}, cost: {total_cost_usd: $c, total_duration_ms: $ms},
      context_window: {used_percentage: 31, context_window_size: $ctx}}' \
    | bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g'
}

# A repo with an upstream, one commit ahead and one behind.
git init -q --bare -b main "$WORK/origin.git"
git clone -q "$WORK/origin.git" "$WORK/repo" 2>/dev/null
git -C "$WORK/repo" commit -q --allow-empty -m one
git -C "$WORK/repo" push -q -u origin main 2>/dev/null
git clone -q "$WORK/origin.git" "$WORK/other" 2>/dev/null
git -C "$WORK/other" commit -q --allow-empty -m theirs
git -C "$WORK/other" push -q origin main 2>/dev/null
git -C "$WORK/repo" fetch -q
git -C "$WORK/repo" commit -q --allow-empty -m mine

out=$(run "$WORK/repo" 1.5 600000)
check "branch prefix" "$out" "git:main"
check "ahead count" "$out" "↑1"
check "behind count" "$out" "↓1"
check "spend rate" "$out" '$9.00/h'
check "no worktree in main checkout" "$out" "worktree:" absent

out=$(run "$WORK/repo" 1.5 30000)
check "no spend rate under a minute" "$out" "/h" absent

git -C "$WORK/repo" worktree add -q "$WORK/feature-wt" -b feature 2>/dev/null
out=$(run "$WORK/feature-wt" 0 0)
check "linked worktree shown" "$out" "worktree:feature-wt"
check "no ahead/behind without upstream" "$out" "↑" absent

out=$(run "$WORK/repo" 0 0 200000)
check "context size after percentage" "$out" "31%/200k"
out=$(run "$WORK/repo" 0 0 1000000)
check "context size in millions" "$out" "31%/1M"
out=$(run "$WORK/repo" 0 0 1500000)
check "fractional millions" "$out" "31%/1.5M"
out=$(run "$WORK/repo" 0 0 0)
check "no size when unknown" "$out" "31%/" absent

exit "$failed"
