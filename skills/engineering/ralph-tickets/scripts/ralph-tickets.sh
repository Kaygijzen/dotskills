#!/usr/bin/env bash
# Ralph loop for tracker tickets: implements one ready ticket of a feature per
# fresh headless Claude session, until the frontier is empty.
#
# Usage (from the repo root):
#   RALPH_ALLOWED_TOOLS="Bash(npm test:*),mcp__github__issue_read" ralph-tickets.sh <feature-slug> [max-iterations]
#
# Env:
#   RALPH_ALLOWED_TOOLS  extra allowed tools: verify commands and the tracker's MCP tools (comma-separated)
#   RALPH_MODEL          model for the iterations (default sonnet)
#   RALPH_MAX_TURNS      max agent turns per iteration (default 60)
#
# Stops when: an iteration writes .ralph-done (frontier empty, exit 0), an
# iteration writes .ralph-stop, two iterations in a row make no commit, or max
# iterations is reached (exit 1).

set -euo pipefail

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
[[ $# -lt 1 ]] && usage 1

feature="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
prompt_file="$script_dir/../prompt.md"
state="$PWD/.scratch/$feature/.tracker.json"
stop_file=".ralph-stop"
done_file=".ralph-done"
log_dir=".ralph/$feature"

# --- preflight ---------------------------------------------------------------
command -v claude >/dev/null || { echo "claude CLI not found on PATH" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq not found on PATH" >&2; exit 1; }
[[ -f "$prompt_file" ]] || { echo "Missing prompt: $prompt_file" >&2; exit 1; }
[[ "$feature" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "Feature slug must be kebab-case" >&2; exit 1; }
[[ -f "$state" ]] || { echo "No $state. Run this from the repo root, after /to-tracker." >&2; exit 1; }

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo "Refusing to run on '$branch'. Switch to a feature branch or worktree first." >&2
  exit 1
fi
for f in "$stop_file" "$done_file"; do
  if [[ -f "$f" ]]; then
    echo "$f exists from an earlier run:" >&2
    cat "$f" >&2
    echo "Resolve it (e.g. with /ralph-tickets $feature), delete the file, and rerun." >&2
    exit 1
  fi
done

# Tickets .tracker.json still lists as open: an upper bound, since it can be stale.
open_tickets() { jq '[.tickets[] | select(.state != "closed")] | length' "$state"; }

remaining="$(open_tickets)"
max="${2:-$((remaining + 3))}"
allowed="Bash(git add:*),Bash(git commit:*),Bash(git status:*),Bash(git diff:*),Bash(git log:*),Read,Edit,Write,Glob,Grep"
if command -v rtk >/dev/null; then
  allowed="$allowed,Bash(rtk git add:*),Bash(rtk git commit:*),Bash(rtk git status:*),Bash(rtk git diff:*),Bash(rtk git log:*)"
fi
[[ -n "${RALPH_ALLOWED_TOOLS:-}" ]] && allowed="$allowed,$RALPH_ALLOWED_TOOLS"

claude_args=(-p --permission-mode acceptEdits --allowedTools "$allowed" --max-turns "${RALPH_MAX_TURNS:-60}" --model "${RALPH_MODEL:-sonnet}")

prompt="$(sed "s/{{FEATURE}}/$feature/g" "$prompt_file")"
mkdir -p "$log_dir"

# Keep logs and the marker files out of the iterations' `git add -A` commits.
exclude_file="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$exclude_file")"
touch "$exclude_file"
for pattern in ".ralph/" ".ralph-stop" ".ralph-done"; do
  grep -qxF "$pattern" "$exclude_file" || echo "$pattern" >> "$exclude_file"
done

echo "Ralph: feature '$feature' on branch '$branch', $remaining open ticket(s), max $max iteration(s)"
echo "Logs: $log_dir/"

# --- loop --------------------------------------------------------------------
stalled=0
for ((i = 1; i <= max; i++)); do
  before="$(git rev-parse HEAD)"

  echo "── iteration $i/$max ──"
  if ! claude "${claude_args[@]}" "$prompt" 2>&1 | tee "$log_dir/iter-$i.log"; then
    echo "⚠ claude exited non-zero in iteration $i (see $log_dir/iter-$i.log)"
  fi

  if [[ -f "$done_file" ]]; then
    echo "✅ Frontier empty after $((i - 1)) ticket(s): $(cat "$done_file")"
    exit 0
  fi
  if [[ -f "$stop_file" ]]; then
    echo "⏸ Stopped by iteration $i:"
    cat "$stop_file"
    exit 1
  fi

  # A ticket done means a new commit; no commit means no progress.
  if [[ "$(git rev-parse HEAD)" == "$before" ]]; then
    stalled=$((stalled + 1))
    echo "No commit this iteration ($stalled in a row)."
    if [[ $stalled -ge 2 ]]; then
      echo "⏸ Stopped: two iterations without progress. Check the logs and notes.md."
      exit 1
    fi
  else
    stalled=0
  fi
done

echo "⏸ Reached max iterations ($max)."
exit 1
