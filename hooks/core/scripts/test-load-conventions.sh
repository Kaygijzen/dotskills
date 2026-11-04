#!/usr/bin/env bash
# Tests load-conventions.sh. Usage: hooks/core/scripts/test-load-conventions.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOK="$DIR/load-conventions.sh"
CONVENTIONS="$(cd "$DIR/../../.." && pwd -P)/conventions/AGENTS.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
mkdir -p "$tmp/c"

# $1 label, $2 expect "print" or "silent", $3 hook (default: the real one), $4 source
check() {
  local label="$1" want="$2" hook="${3:-$HOOK}" src="${4:-startup}" out rc
  out="$(printf '{"hook_event_name":"SessionStart","source":"%s"}' "$src" | CLAUDE_CONFIG_DIR="$tmp/c" "$hook" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then echo "FAIL $label: exit $rc"; fail=1; return; fi
  if [[ "$want" == print && "$out" != *"# Working conventions"* ]]; then
    echo "FAIL $label: expected the conventions, got: ${out:0:80}"; fail=1
  elif [[ "$want" == silent && -n "$out" ]]; then
    echo "FAIL $label: expected no output, got: ${out:0:80}"; fail=1
  else
    echo "ok   $label -> $want"
  fi
}
# Writes a CLAUDE.md with a block importing $1 (spaces escaped like install.sh does).
block() { printf '# My own notes\n\n# >>> dotskills conventions >>>\n# Managed by dotskills\n@%s\n# <<< dotskills conventions <<<\n' "${1// /\\ }" > "$tmp/c/CLAUDE.md"; }

check "no CLAUDE.md" print
printf '# My own notes\n' > "$tmp/c/CLAUDE.md"
check "CLAUDE.md without the block" print
block "$CONVENTIONS"
check "block that resolves" silent
check "block that resolves, on compact" silent "" compact
block "/nonexistent/dotskills/conventions/AGENTS.md"
check "block pointing at a deleted clone" print
mkdir -p "$tmp/sp ace"; cp "$CONVENTIONS" "$tmp/sp ace/AGENTS.md"; block "$tmp/sp ace/AGENTS.md"
check "block with a space in the path" silent
block "$CONVENTIONS"; sed -i.bak 's/$/\r/' "$tmp/c/CLAUDE.md"
check "CRLF CLAUDE.md with the block" silent
rm -f "$tmp/c/CLAUDE.md"
check "on compact without the block" print "" compact

# Hook in a copy of the repo without conventions/AGENTS.md: silent, exit 0.
mkdir -p "$tmp/repo/hooks/core/scripts"; cp "$HOOK" "$tmp/repo/hooks/core/scripts/"
check "conventions file missing" silent "$tmp/repo/hooks/core/scripts/load-conventions.sh"

# Hook output over 10,000 characters is cut off by Claude Code.
size="$(echo '{}' | CLAUDE_CONFIG_DIR="$tmp/c" "$HOOK" | wc -c)"
if (( size < 9000 )); then echo "ok   output is $size chars (limit 10,000)"; else echo "FAIL output is $size chars; Claude Code truncates hook output over 10,000"; fail=1; fi

[[ $fail -eq 0 ]] && echo "All load-conventions tests passed." || { echo "load-conventions tests failed."; exit 1; }
