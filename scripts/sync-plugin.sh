#!/usr/bin/env bash
# Rewrites the component path lists in .claude-plugin/plugin.json from the
# domain folders. validate.sh fails when plugin.json is out of sync.
#
#   skills      ./skills/<domain>            (folders holding <name>/SKILL.md)
#   agents      ./agents/<domain>/<name>.md  (the plugin schema takes files, not folders)
#   hooks       ./hooks/<domain>/hooks.json
#   mcpServers  ./mcp/<domain>/.mcp.json
#
# Usage: scripts/sync-plugin.sh [--print]   (--print writes to stdout instead)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PLUGIN="$REPO_DIR/.claude-plugin/plugin.json"

# Prints one "./relative" path per line, sorted, for the given glob under the repo.
list() {
  local p
  ( cd "$REPO_DIR" && compgen -G "$1" || true ) | LC_ALL=C sort | while read -r p; do
    [[ -n "$p" ]] && echo "./$p"
  done
}

# Prints the plugin.json that matches the folders.
build() {
  local skills agents hooks mcp
  skills="$(list 'skills/*/' | sed 's#/$##' | jq -R . | jq -s .)"
  agents="$(list 'agents/*/*.md' | jq -R . | jq -s .)"
  hooks="$(list 'hooks/*/hooks.json' | jq -R . | jq -s .)"
  mcp="$(list 'mcp/*/.mcp.json' | jq -R . | jq -s .)"
  jq --argjson s "$skills" --argjson a "$agents" --argjson h "$hooks" --argjson m "$mcp" '
    del(.skills, .agents, .hooks, .mcpServers)
    | . + (if ($s|length) > 0 then {skills: $s} else {} end)
        + (if ($a|length) > 0 then {agents: $a} else {} end)
        + (if ($h|length) > 0 then {hooks: $h} else {} end)
        + (if ($m|length) > 0 then {mcpServers: $m} else {} end)
  ' "$PLUGIN"
}

main() {
  if [[ "${1:-}" == "--print" ]]; then
    build
    return
  fi
  local tmp
  tmp="$(mktemp)"
  build > "$tmp"
  cat "$tmp" > "$PLUGIN"
  rm -f "$tmp"
  echo "Synced .claude-plugin/plugin.json"
}

main "$@"
