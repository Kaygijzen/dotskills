#!/usr/bin/env bash
# Summarises Claude Code session logs for the retro skill. Prints counts and short labels, not
# conversation text (`list` shows each session's first prompt, cut to 70 characters).
#
#   session-digest.sh list   [project] [--days N] [--all]   25 newest sessions: date, size, project, id, first prompt
#   session-digest.sh show   [id|path]                      one session; default: newest one for this directory
#   session-digest.sh shapes [project] [--days N] [--all]   Bash command shapes across sessions
#
# project is a substring of the log folder name. --days defaults to 30. --all also reads the
# scratchpad folders (-tmp-*), which are skipped by default.
# A shape is the first command of a Bash call, leaving off a leading cd and VAR=value lines: the program
# name plus a lowercase subcommand if there is one. `cd x && A=1 git log -3 | head` is `git log`.
# Arguments, paths and values never reach the output.
# Logs: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<cwd, non-alphanumerics as dashes>/<session-id>.jsonl
# Exit 2 on bad usage or when there are no logs.
set -uo pipefail

root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
die() { echo "session-digest.sh: $*" >&2; exit 2; }
[[ -d "$root" ]] || die "no session logs at $root"
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

read -r -d '' SHAPE <<'EOF'
def shape:
  [ splits("&&|\\|\\||;|\\||\n")
    | sub("^[ \\t(]+"; "")
    | sub("^([A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|'[^']*'|[^ \\t]*)[ \\t]+)+"; "")
    | select(length > 0 and (test("^cd([ \\t]|$)") | not) and (test("^[A-Za-z_][A-Za-z0-9_]*=") | not)) ] | .[0] // ""
  | [splits("[ \\t]+")] as $w
  | ($w[0] // "") as $p
  | if ($p | test("^[A-Za-z0-9._/][A-Za-z0-9._/+-]*$") | not) then "(other)"
    else ($p | split("/") | last) as $prog
      | if ($w[1] // "" | test("^[a-z][a-z0-9-]*$")) then "\($prog) \($w[1])" else $prog end
    end;
EOF

read -r -d '' FIRST <<'EOF'
def prompt: if test("<command-name>")
            then ((capture("<command-name>(?<n>[^<]*)</command-name>").n) as $n
                  | if $n == "/clear" then "" else "\($n) \((capture("<command-args>(?<a>[^<]*)</command-args>")? // {a: ""}) | .a)" end)
            else . end;
[ first(inputs
    | select(.type == "user" and ((.isMeta // false) | not))
    | {t: (.timestamp // "?"),
       p: ((.message.content // "") | if type == "string" then prompt else (map(select(.type? == "text").text) | join(" ")) end)}
    | select(.p != "" and (.p | startswith("<") | not))) ]
| .[0] // {t: "?", p: ""}
| "\(.t[0:10])\t\(.p | gsub("[\\n\\t\\r]+"; " ") | .[0:70])"
EOF

read -r -d '' SHOW <<'EOF'
def tsize: if type == "string" then length
           elif type == "array" then (map(.text? // "") | join("") | length)
           else 0 end;
def secs: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
def counted: group_by(.) | map({n: .[0], c: length}) | sort_by(-.c) | map("\(.n) \(.c)") | join(", ");
. as $all
| [$all[] | select(.type == "assistant")] as $asst
| ($asst | group_by(.message.id) | map(last)) as $reqs
| [$asst[].message.content[]? | select(.type == "tool_use")] as $uses
| [$all[] | select(.type == "user") | .message.content | arrays | .[] | select(.type == "tool_result")] as $res
| ($uses | map({key: .id, value: .name}) | from_entries) as $names
| ($reqs | map(.message.usage // {})) as $u
| ($u | map((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))) as $ctx
| [$all[] | .timestamp? | select(. != null)] as $ts
| ([$all[] | .cwd? | select(. != null)] | .[0] // "?") as $cwd
| ([$res[] | select(.is_error == true) | ($names[.tool_use_id] // "?")]) as $errs
| "project:  \($cwd)",
  "span:     \(if ($ts | length) > 0 then (($ts | max | secs) - ($ts | min | secs)) / 60 | floor else 0 end) min, \($ts | min // "?") to \($ts | max // "?")",
  "model:    \($reqs | map(.message.model // "?") | group_by(.) | max_by(length) | .[0] // "?")",
  "requests: \($reqs | length)",
  "tokens:   cache-read \($u | map(.cache_read_input_tokens // 0) | add // 0), peak context \($ctx | max // 0), output \($u | map(.output_tokens // 0) | add // 0)",
  "tools:    \(if ($uses | length) > 0 then ($uses | map(.name) | counted) else "none" end)",
  "errors:   \(if ($errs | length) > 0 then ($errs | counted) else "none" end)",
  "biggest results (chars):",
  ($res | map({n: ($names[.tool_use_id] // "?"), c: (.content | tsize)}) | sort_by(-.c) | .[0:5] | .[] | "  \(.n) \(.c)"),
  "bash shapes:",
  ([$uses[] | select(.name == "Bash") | .input.command? // "" | shape] | group_by(.) | map({n: .[0], c: length}) | sort_by(-.c) | .[0:8] | .[] | "  \(.n) \(.c)")
EOF

cmd="${1:-}"; shift || true
project="" days=30 all=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) days="${2:-}"; [[ "$days" =~ ^[0-9]+$ ]] || die "--days needs a number"; shift ;;
    --all) all=1 ;;
    -*) die "unknown option: $1" ;;
    *) project="$1" ;;
  esac
  shift
done

# Session logs from the last $days days, minus scratchpad folders unless --all, filtered by project.
logs() {
  local f d
  find "$root" -mindepth 2 -maxdepth 2 -name '*.jsonl' -mtime "-$days" | while IFS= read -r f; do
    d="${f%/*}"; d="${d##*/}"
    [[ "$all" == 1 || "$d" != -tmp-* ]] || continue
    [[ -z "$project" || "$d" == *"$project"* ]] || continue
    echo "$f"
  done
}

list() {
  local f d id date prompt kb
  while IFS= read -r f; do printf '%s\t%s\n' "$(mtime "$f")" "$f"; done < <(logs) | sort -rn | head -n 25 |
  while IFS=$'\t' read -r _ f; do
    d="${f%/*}"; d="${d##*/}"; id="${f##*/}"; id="${id%.jsonl}"
    IFS=$'\t' read -r date prompt <<<"$(jq -rn "$FIRST" "$f" 2>/dev/null)"
    kb=$(( $(wc -c <"$f") / 1024 ))
    printf '%s  %6sK  %s  %s  %s\n' "${date:-?}" "$kb" "$(sed 's/^-home-[^-]*-//' <<<"$d")" "$id" "$prompt"
  done
}

show() {
  local arg="$project" f dir matches
  if [[ -z "$arg" ]]; then
    dir="$root/$(printf '%s' "$PWD" | sed 's/[^A-Za-z0-9]/-/g')"
    [[ -d "$dir" ]] || die "no logs for $PWD under $root; pass a session id (see: list)"
    f="$(ls -t "$dir"/*.jsonl 2>/dev/null | head -n 1)"
    [[ -n "$f" ]] || die "no sessions in $dir"
  elif [[ -f "$arg" ]]; then
    f="$arg"
  else
    matches="$(find "$root" -mindepth 2 -maxdepth 2 -name "$arg*.jsonl")"
    [[ -n "$matches" ]] || die "no session starting with $arg (see: list)"
    [[ "$(wc -l <<<"$matches")" -eq 1 ]] || die "$arg matches several sessions; use more of the id"
    f="$matches"
  fi
  echo "session:  ${f##*/}"
  jq -s -r "$SHAPE $SHOW" "$f" || die "could not read $f"
}

shapes() {
  local f sid
  echo "calls sessions  shape"
  while IFS= read -r f; do
    sid="${f##*/}"
    jq -r --arg sid "$sid" "$SHAPE"' select(.type == "assistant") | .message.content[]?
      | select(.type == "tool_use" and .name == "Bash")
      | "\($sid)\t\(.input.command? // "" | shape)"' "$f" 2>/dev/null
  done < <(logs) | awk -F'\t' '
    { k = $2; n[k]++; if (!(($1 SUBSEP k) in seen)) { seen[$1 SUBSEP k] = 1; s[k]++ } }
    END { for (k in n) printf "%5d %8d  %s\n", n[k], s[k], k }' | sort -rn | head -n 25
}

case "$cmd" in
  list) list ;;
  show) show ;;
  shapes) shapes ;;
  *) sed -n '2,/^set /p' "$0" | sed '$d' >&2; exit 2 ;;
esac
