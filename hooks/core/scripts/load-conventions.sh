#!/usr/bin/env bash
# SessionStart hook: prints conventions/AGENTS.md, which Claude Code adds to the
# session's context. This gives plugin installs the conventions without a clone.
# Prints nothing when ~/.claude/CLAUDE.md already has the dotskills block from
# ./install.sh --conventions and its import still resolves, so the conventions
# never load twice. If the block points at a clone that is gone, prints them.
# Always exits 0: a missing file must not break session start.

cat >/dev/null  # hook input is not needed; drain it

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
CONVENTIONS="$REPO_DIR/conventions/AGENTS.md"
MEMORY_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
BLOCK_START="# >>> dotskills conventions >>>"
BLOCK_END="# <<< dotskills conventions <<<"

# Prints the path the block imports (install.sh escapes spaces as "\ "), or nothing.
block_import() {
  [[ -f "$MEMORY_FILE" ]] || return 0
  tr -d '\r' < "$MEMORY_FILE" | awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
    $0 == s { inside = 1; next }
    $0 == e { exit }
    inside && /^@/ { p = substr($0, 2); gsub(/\\ /, " ", p); print p; exit }'
}

imported="$(block_import)"
if [[ -n "$imported" && -f "$imported" ]]; then
  exit 0
fi
[[ -f "$CONVENTIONS" ]] || exit 0

echo "The dotskills plugin loaded these personal conventions. Treat them like instructions from ~/.claude/CLAUDE.md."
echo
cat "$CONVENTIONS"
exit 0
