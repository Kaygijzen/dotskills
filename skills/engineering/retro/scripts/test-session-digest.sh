#!/usr/bin/env bash
# Tests session-digest.sh on fabricated logs. Usage: skills/engineering/retro/scripts/test-session-digest.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT="$DIR/session-digest.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
export CLAUDE_CONFIG_DIR="$tmp/cfg"
P="$CLAUDE_CONFIG_DIR/projects"

ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# check <name> <output> <grep -E pattern that must match>
has() { grep -Eq -- "$3" <<<"$2" && ok "$1" || { bad "$1"; echo "$2" | sed 's/^/     | /'; }; }
lacks() { grep -Eq -- "$3" <<<"$2" && { bad "$1"; echo "$2" | sed 's/^/     | /'; } || ok "$1"; }

big="$(head -c 5000 /dev/zero | tr '\0' x)"
user() { jq -nc --arg t "$1" --argjson c "$2" '{type: "user", timestamp: $t, cwd: "/home/u/projects/demo", message: {role: "user", content: $c}}'; }
meta() { jq -nc --arg t "$1" --argjson c "$2" '{type: "user", isMeta: true, timestamp: $t, message: {role: "user", content: $c}}'; }
# asst <ts> <msg id> <input> <cache read> <cache create> <content block json>
asst() { jq -nc --arg t "$1" --arg id "$2" --argjson i "$3" --argjson r "$4" --argjson w "$5" --argjson b "$6" \
  '{type: "assistant", timestamp: $t, message: {id: $id, model: "m-test", role: "assistant", content: [$b],
    usage: {input_tokens: $i, cache_read_input_tokens: $r, cache_creation_input_tokens: $w, output_tokens: 7}}}'; }
bash_use() { jq -nc --arg id "$1" --arg c "$2" '{type: "tool_use", id: $id, name: "Bash", input: {command: $c}}'; }
result() { jq -nc --arg id "$1" --argjson e "$2" --argjson c "$3" '{type: "tool_result", tool_use_id: $id, is_error: $e, content: $c}'; }
tr_user() { user "$1" "[$2]"; }

mkdir -p "$P/-home-u-projects-demo" "$P/-home-u-projects-other" "$P/-tmp-claude-1000--x-scratchpad"
{
  meta 2026-11-01T10:00:00.000Z '"<local-command-caveat>ignore</local-command-caveat>"'
  user 2026-11-01T10:00:05.000Z '"fix the build"'
  asst 2026-11-01T10:01:00.000Z m1 10 1000 0 "$(bash_use t1 'cd /x && git log --oneline | head')"
  asst 2026-11-01T10:01:01.000Z m1 10 1000 0 '{"type":"thinking","thinking":"x"}'
  tr_user 2026-11-01T10:02:00.000Z "$(result t1 false '"ok"')"
  asst 2026-11-01T10:03:00.000Z m2 20 2000 5 "$(bash_use t2 'TOKEN=abc123 curl https://example.com/x')"
  tr_user 2026-11-01T10:04:00.000Z "$(result t2 true '"boom"')"
  asst 2026-11-01T10:04:30.000Z m2b 1 1 1 "$(bash_use t2b $'D=/secret/dir\nuv run pytest "$D"')"
  asst 2026-11-01T10:05:00.000Z m3 30 3000 0 "$(bash_use t3 'cat /secret/path')"
  tr_user 2026-11-01T10:07:00.000Z "$(result t3 false "$(jq -nc --arg x "$big" '[{type: "text", text: $x}]')")"
} > "$P/-home-u-projects-demo/aaaa1111.jsonl"
{
  user 2026-11-02T09:00:00.000Z '"second session"'
  asst 2026-11-02T09:01:00.000Z n1 1 1 1 "$(bash_use u1 'git log -1')"
} > "$P/-home-u-projects-other/bbbb2222.jsonl"
{
  user 2026-11-02T09:00:00.000Z '"scratch"'
  asst 2026-11-02T09:01:00.000Z s1 1 1 1 "$(bash_use v1 'git log -2')"
} > "$P/-tmp-claude-1000--x-scratchpad/cccc3333.jsonl"
{
  user 2026-11-03T08:00:00.000Z '"<command-name>/clear</command-name>\n<command-args></command-args>"'
  user 2026-11-03T08:00:01.000Z '"<command-message>retro</command-message>\n<command-name>/retro</command-name>\n<command-args>session abc</command-args>"'
} > "$P/-home-u-projects-demo/eeee5555.jsonl"
touch -t 202001010001 "$P/-home-u-projects-demo/eeee5555.jsonl"
touch -t 202001010000 "$P/-home-u-projects-demo/aaaa1111.jsonl"   # recent enough only with a large --days
touch "$P/-home-u-projects-other/bbbb2222.jsonl" "$P/-tmp-claude-1000--x-scratchpad/cccc3333.jsonl"

run() { "$SCRIPT" "$@" 2>&1; }

# list
out="$(run list --days 99999)"
has   "list shows the first real prompt, not the caveat" "$out" "aaaa1111  fix the build"
has   "list shows the project without the home prefix"   "$out" "  projects-demo  aaaa1111|  projects-other  bbbb2222"
has   "list shows a slash command with its arguments"    "$out" "eeee5555  /retro session abc"
lacks "list skips scratchpad folders"                   "$out" "cccc3333"
has   "list --all includes scratchpad folders"           "$(run list --days 99999 --all)" "cccc3333"
has   "list filters by project"                          "$(run list other --days 99999)" "bbbb2222"
lacks "list project filter drops the rest"              "$(run list other --days 99999)" "aaaa1111"
lacks "list --days drops old sessions"                   "$(run list --days 30)" "aaaa1111"
has   "list is newest first"                             "$(run list --days 99999 | head -n 1)" "bbbb2222"

# show
out="$(run show aaaa1)"
has "show counts API requests once per message id" "$out" "^requests: 4$"
has "show sums cache reads"                        "$out" "cache-read 6001, peak context 3030, output 28"
has "show spans the session"                       "$out" "^span:     7 min"
has "show counts tools"                            "$out" "^tools:    Bash 4$"
has "show counts errors by tool"                   "$out" "^errors:   Bash 1$"
has "show ranks the biggest result"                "$out" "^  Bash 5000$"
has "show lists bash shapes"                       "$out" "^  git log 1$"
has "show skips a bare VAR=value line"             "$out" "^  uv run 1$"
lacks "show prints no arguments, paths or values"  "$out" "abc123|/secret|example\.com|oneline"
has "show takes a path"                            "$(run show "$P/-home-u-projects-demo/aaaa1111.jsonl")" "^requests: 4$"
mkdir -p "$tmp/work"
enc="$(printf '%s' "$tmp/work" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$P/$enc"; cp "$P/-home-u-projects-other/bbbb2222.jsonl" "$P/$enc/dddd4444.jsonl"
has "show defaults to the newest session of this directory" "$(cd "$tmp/work" && "$SCRIPT" show 2>&1)" "^session:  dddd4444.jsonl"
rm -rf "${P:?}/$enc"   # lives under a -tmp-* folder name; keep it out of the --all counts below
run show zzzz >/dev/null; [[ $? -eq 2 ]] && ok "show with an unknown id exits 2" || bad "show with an unknown id exits 2"

# shapes
out="$(run shapes --days 99999)"
has   "shapes counts calls and sessions"    "$out" "^ +2 +2  git log$"
has   "shapes drops arguments"              "$out" "^ +1 +1  curl$"
lacks "shapes never prints values or paths" "$out" "abc123|/secret|example\.com"
has   "shapes --all adds scratchpad calls"  "$(run shapes --days 99999 --all)" "^ +3 +3  git log$"
has   "shapes keeps the program of a path"  "$out" "^ +1 +1  cat$"

# usage
run bogus >/dev/null; [[ $? -eq 2 ]] && ok "unknown command exits 2" || bad "unknown command exits 2"
run list --days x >/dev/null; [[ $? -eq 2 ]] && ok "bad --days exits 2" || bad "bad --days exits 2"
CLAUDE_CONFIG_DIR="$tmp/none" "$SCRIPT" list >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "missing logs dir exits 2" || bad "missing logs dir exits 2"

exit "$fail"
