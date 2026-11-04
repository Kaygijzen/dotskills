#!/usr/bin/env bash
# Copies statusline/statusline.sh to ~/.claude/statusline.sh and sets `statusLine`
# in ~/.claude/settings.json. For plugin installs, which cannot set a statusline.
# Copies instead of linking: the plugin folder changes with every update.
# Same safety rules as ./install.sh --statusline-settings: backs up settings.json
# once, never overwrites a different statusLine, never replaces someone else's script.
# Usage: install-statusline.sh   (CLAUDE_CONFIG_DIR overrides ~/.claude)

set -uo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
SRC="$REPO_DIR/statusline/statusline.sh"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST="$CONFIG_DIR/statusline.sh"
SETTINGS="$CONFIG_DIR/settings.json"
MARKER="Claude Code session status line"  # in the vendored script's header

command -v jq >/dev/null 2>&1 || { echo "ERROR   jq not found. The statusline needs it. Install it with: brew install jq (macOS), sudo apt install jq (Debian/Ubuntu or WSL), winget install jqlang.jq (Windows)"; exit 1; }
[[ -f "$SRC" ]] || { echo "ERROR   $SRC not found"; exit 1; }
mkdir -p "$CONFIG_DIR"

# --- the script ---
if [[ -L "$DEST" && ! -e "$DEST" ]]; then
  rm "$DEST"  # dangling link, e.g. to a deleted clone; replaced below
fi
if [[ -L "$DEST" ]]; then
  if grep -qF "$MARKER" "$DEST"; then
    echo "ok      $DEST is a symlink to the dotskills statusline (from ./install.sh); leaving it alone"
  else
    echo "ERROR   $DEST is a symlink to $(readlink "$DEST"), not the dotskills statusline; not replacing it"; exit 1
  fi
elif [[ -e "$DEST" ]] && ! grep -qF "$MARKER" "$DEST"; then
  echo "ERROR   $DEST exists and is not the dotskills statusline; not replacing it"; exit 1
elif [[ -f "$DEST" ]] && cmp -s "$SRC" "$DEST"; then
  echo "ok      $DEST is up to date"
else
  [[ -e "$DEST" ]] && verb="updated" || verb="copied "
  cp "$SRC" "$DEST" && chmod +x "$DEST" || { echo "ERROR   could not write $DEST"; exit 1; }
  echo "$verb $DEST"
fi

# --- settings.json ---
want="$(jq -cn --arg c "$DEST" '{type: "command", command: $c, timeout: 10}')"
write_settings() {
  local tmp
  tmp="$(mktemp "$SETTINGS.XXXXXX")" || return 1
  cat > "$tmp" && mv "$tmp" "$SETTINGS" || { rm -f "$tmp"; return 1; }
}
if [[ ! -f "$SETTINGS" ]]; then
  jq -n --argjson v "$want" '{statusLine: $v}' | write_settings || exit 1
  echo "added   statusLine to $SETTINGS (new file)"; exit 0
fi
if ! jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
  echo "ERROR   $SETTINGS is not a valid JSON object; leaving it alone"; exit 1
fi
current="$(jq -c '.statusLine // empty' "$SETTINGS")"
# Recognised by its command alone: Claude Code drops `timeout` when it rewrites
# settings.json (e.g. on a plugin install).
if [[ "$(jq -r '.statusLine.command? // empty' "$SETTINGS")" == "$DEST" ]]; then
  echo "ok      statusLine in $SETTINGS"; exit 0
fi
if [[ -n "$current" ]]; then
  echo "WARN    $SETTINGS already sets statusLine to $current; not overwriting (remove it first to use this one)"; exit 1
fi
[[ -e "$SETTINGS.dotskills.bak" ]] || cp -p "$SETTINGS" "$SETTINGS.dotskills.bak"
jq --argjson v "$want" '.statusLine = $v' "$SETTINGS" | write_settings || exit 1
echo "added   statusLine to $SETTINGS (backup: $SETTINGS.dotskills.bak)"
