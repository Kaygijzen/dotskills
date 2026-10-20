#!/usr/bin/env bash
# Ralph loop for OpenSpec: applies one task of a change per fresh headless
# Claude session, until every task in tasks.md is ticked.
#
# Usage (from the repo root):
#   RALPH_ALLOWED_TOOLS="Bash(flutter:*),Bash(dart:*)" ralph.sh <change-name> [max-iterations]
#
# Env:
#   RALPH_ALLOWED_TOOLS  extra allowed tools for the project's verify commands (comma-separated)
#   RALPH_MODEL          optional model for the iterations
#   RALPH_MAX_TURNS      max agent turns per iteration (default 60)
#
# Stops when: all tasks are ticked (exit 0), an iteration writes .ralph-stop,
# two iterations in a row make no progress, or max iterations is reached (exit 1).

set -euo pipefail

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
[[ $# -lt 1 ]] && usage 1

change="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
prompt_file="$script_dir/../prompt.md"
change_dir="openspec/changes/$change"
tasks="$change_dir/tasks.md"
stop_file=".ralph-stop"
log_dir=".ralph/$change"

open_tasks() { grep -cE '^[[:space:]]*- \[ \]' "$tasks" || true; }

# --- preflight ---------------------------------------------------------------
command -v claude >/dev/null || { echo "claude CLI not found on PATH" >&2; exit 1; }
[[ -f "$prompt_file" ]] || { echo "Missing prompt: $prompt_file" >&2; exit 1; }
[[ -f "$tasks" ]] || { echo "No $tasks. Run this from the repo root with an existing change." >&2; exit 1; }
[[ "$change" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "Change name must be kebab-case" >&2; exit 1; }

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo "Refusing to run on '$branch'. Switch to a change branch or worktree first." >&2
  exit 1
fi
if [[ -f "$stop_file" ]]; then
  echo "$stop_file exists from an earlier run:" >&2
  cat "$stop_file" >&2
  echo "Resolve it (e.g. with /ralph-apply $change), delete the file, and rerun." >&2
  exit 1
fi

remaining="$(open_tasks)"
max="${2:-$((remaining + 5))}"
allowed="Bash(git add:*),Bash(git commit:*),Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(openspec:*),Read,Edit,Write,Glob,Grep"
# A PreToolUse hook from rtk rewrites git commands to `rtk git ...`, which the
# rules above don't match, so allow the rewritten forms too.
if command -v rtk >/dev/null; then
  allowed="$allowed,Bash(rtk git add:*),Bash(rtk git commit:*),Bash(rtk git status:*),Bash(rtk git diff:*),Bash(rtk git log:*)"
fi
[[ -n "${RALPH_ALLOWED_TOOLS:-}" ]] && allowed="$allowed,$RALPH_ALLOWED_TOOLS"

claude_args=(-p --permission-mode acceptEdits --allowedTools "$allowed" --max-turns "${RALPH_MAX_TURNS:-60}")
[[ -n "${RALPH_MODEL:-}" ]] && claude_args+=(--model "$RALPH_MODEL")

prompt="$(sed "s/{{CHANGE}}/$change/g" "$prompt_file")"
mkdir -p "$log_dir"

echo "Ralph: change '$change' on branch '$branch', $remaining open task(s), max $max iteration(s)"
echo "Logs: $log_dir/"

# --- loop --------------------------------------------------------------------
stalled=0
for ((i = 1; i <= max; i++)); do
  before="$(open_tasks)"
  if [[ "$before" -eq 0 ]]; then
    echo "✅ All tasks in $tasks are ticked after $((i - 1)) iteration(s)."
    exit 0
  fi

  echo "── iteration $i/$max · $before open ──"
  if ! claude "${claude_args[@]}" "$prompt" 2>&1 | tee "$log_dir/iter-$i.log"; then
    echo "⚠ claude exited non-zero in iteration $i (see $log_dir/iter-$i.log)"
  fi

  if [[ -f "$stop_file" ]]; then
    echo "⏸ Stopped by iteration $i:"
    cat "$stop_file"
    exit 1
  fi

  after="$(open_tasks)"
  if [[ "$after" -ge "$before" ]]; then
    stalled=$((stalled + 1))
    echo "No task ticked this iteration ($stalled in a row)."
    if [[ $stalled -ge 2 ]]; then
      echo "⏸ Stopped: two iterations without progress. Check the logs and notes.md."
      exit 1
    fi
  else
    stalled=0
  fi
done

echo "⏸ Reached max iterations ($max) with $(open_tasks) task(s) open."
exit 1
