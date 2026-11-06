#!/usr/bin/env bash
# Ralph loop for OpenSpec: applies one task of a change per fresh headless
# Claude session, until every task in tasks.md is ticked.
#
# Usage (from the repo root):
#   RALPH_ALLOWED_TOOLS="Bash(flutter:*),Bash(dart:*)" ralph.sh <change-name> [max-iterations]
#
# Env:
#   RALPH_ALLOWED_TOOLS  extra allowed tools for the project's verify commands (comma-separated)
#   RALPH_MODEL          model for the iterations (default sonnet)
#   RALPH_MAX_TURNS      max agent turns per iteration (default 60)
#   RALPH_TOOLS          built-in tools each iteration gets (default Bash,Read,Edit,Write,Glob,Grep)
#
# Stops when: all tasks are ticked (exit 0), an iteration writes .ralph-stop,
# two iterations in a row make no progress, or max iterations is reached (exit 1).

set -euo pipefail

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
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

# Prints the usage line and result of one iteration's JSON log; falls back to the raw file.
show_result() {
  local f="$1"
  if command -v jq >/dev/null && jq -e . "$f" >/dev/null 2>&1; then
    jq -r '"turns \(.num_turns // "?") · cost $\((.total_cost_usd // 0) * 10000 | round / 10000) · in \(.usage.input_tokens // 0) · cache read \(.usage.cache_read_input_tokens // 0) · cache write \(.usage.cache_creation_input_tokens // 0) · out \(.usage.output_tokens // 0)" + (if (.subtype // "success") != "success" then " · " + .subtype else "" end), (.result // empty)' "$f"
  else
    cat "$f"
  fi
}

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

# --tools drops the tool definitions an iteration never uses (web, agents, ...), which
# shrinks the prefix re-read on every turn. --output-format json gives usage per run.
claude_args=(-p --permission-mode acceptEdits --allowedTools "$allowed" --tools "${RALPH_TOOLS:-Bash,Read,Edit,Write,Glob,Grep}" \
  --max-turns "${RALPH_MAX_TURNS:-60}" --model "${RALPH_MODEL:-sonnet}" --output-format json)

prompt="$(sed "s/{{CHANGE}}/$change/g" "$prompt_file")"
mkdir -p "$log_dir"

# Keep logs and the stop file out of the iterations' `git add -A` commits.
# Uses the local exclude file, so the repo's tracked .gitignore is untouched.
exclude_file="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$exclude_file")"
touch "$exclude_file"
for pattern in ".ralph/" ".ralph-stop"; do
  grep -qxF "$pattern" "$exclude_file" || echo "$pattern" >> "$exclude_file"
done

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
  log="$log_dir/iter-$i.json"
  if ! claude "${claude_args[@]}" "$prompt" > "$log"; then
    echo "⚠ claude exited non-zero in iteration $i (see $log)"
  fi
  show_result "$log"

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
