#!/usr/bin/env bash
# Tests for ralph.sh with a stubbed `claude`: tool restriction, JSON logs, usage summary.
# Usage: skills/engineering/ralph-apply/scripts/test-ralph.sh

set -uo pipefail

RALPH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/ralph.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

failed=0
check() {  # check <name> <haystack> <needle> [absent]
  if [[ "${4:-}" == absent ]]; then
    [[ "$2" != *"$3"* ]] && { echo "ok   $1"; return; }
  else
    [[ "$2" == *"$3"* ]] && { echo "ok   $1"; return; }
  fi
  echo "FAIL $1: expected ${4:+no }'$3' in: $2"; failed=1
}

# Stub claude: logs its arguments, ticks the first open task, prints a result per STUB_MODE.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
{ printf '%s\n' "$@"; echo "--end--"; } >> "$STUB_ARGS"
sed -i '0,/- \[ \]/s//- [x]/' openspec/changes/demo/tasks.md
case "${STUB_MODE:-json}" in
  json) echo '{"type":"result","subtype":"success","result":"did task","num_turns":7,"total_cost_usd":0.25,"usage":{"input_tokens":10,"cache_read_input_tokens":900,"cache_creation_input_tokens":50,"output_tokens":20}}' ;;
  plain) echo "plain text output" ;;
  maxturns) echo '{"type":"result","subtype":"error_max_turns","num_turns":60,"total_cost_usd":1.5,"usage":{"input_tokens":1,"cache_read_input_tokens":2,"cache_creation_input_tokens":3,"output_tokens":4}}' ;;
esac
STUB
chmod +x "$WORK/bin/claude"

new_repo() {  # new_repo <name>: a change with two open tasks on a feature branch
  local d="$WORK/$1"
  git init -q -b feature "$d"
  mkdir -p "$d/openspec/changes/demo"
  printf '%s\n' '- [ ] 1.1 first' '- [ ] 1.2 second' > "$d/openspec/changes/demo/tasks.md"
  git -C "$d" add -A && git -C "$d" commit -q -m init
  echo "$d"
}

run() {  # run <repo> [env assignments...]: runs ralph.sh with the stub on PATH
  local d="$1"; shift
  ( cd "$d" && env PATH="$WORK/bin:$PATH" STUB_ARGS="$d/args.log" "$@" bash "$RALPH" demo 2>&1 )
}

# Default run: two iterations, restricted tools, JSON logs, usage summary.
repo="$(new_repo default)"
out="$(run "$repo")"
check "completes"           "$out" "All tasks"
args="$(cat "$repo/args.log")"
check "restricts tools"     "$(grep -A1 -x -- '--tools' <<<"$args" | sed -n 2p)" "Bash,Read,Edit,Write,Glob,Grep"
check "asks for json"       "$(grep -A1 -x -- '--output-format' <<<"$args" | sed -n 2p)" "json"
check "keeps allowedTools"  "$args" "--allowedTools"
check "prompt reads CLAUDE.md only if missing" "$args" "not already in your context"
check "writes json log"     "$(jq -r .num_turns "$repo/.ralph/demo/iter-1.json" 2>&1)" "7"
check "prints usage line"   "$out" "turns 7 · cost \$0.25 · in 10 · cache read 900 · cache write 50 · out 20"
check "prints result"       "$out" "did task"

# RALPH_TOOLS overrides the tool list.
repo="$(new_repo override)"
run "$repo" RALPH_TOOLS="Bash,Read" >/dev/null
check "RALPH_TOOLS override" "$(grep -A1 -x -- '--tools' "$repo/args.log" | sed -n 2p)" "Bash,Read"

# Non-JSON output is shown as is and does not stop the loop.
repo="$(new_repo plain)"
out="$(run "$repo" STUB_MODE=plain)"
check "plain output shown"  "$out" "plain text output"
check "plain still loops"   "$out" "All tasks"

# A run that hit the turn cap shows its subtype.
repo="$(new_repo maxturns)"
out="$(run "$repo" STUB_MODE=maxturns)"
check "shows error subtype" "$out" "error_max_turns"

echo
[[ $failed -eq 0 ]] && echo "all passed" || { echo "FAILED"; exit 1; }
