#!/usr/bin/env bash
# One-time user setup for plugin installs, which cannot set these themselves:
#   - copies statusline/statusline.sh to ~/.claude/statusline.sh and sets `statusLine`
#   - sets `"model": "sonnet"` in ~/.claude/settings.json when no model is set
#   - with --openspec: installs the OpenSpec CLI with npm
#   - with --rtk: installs rtk with its official script
# Copies the statusline instead of linking: the plugin folder changes with every update.
# Same safety rules as ./install.sh: backs up settings.json once, never overwrites a
# different statusLine or model, never replaces someone else's script.
# Each step is independent; the exit code is 1 if any step failed.
# Usage: setup.sh [--openspec] [--rtk] [--no-model-setting]   (CLAUDE_CONFIG_DIR overrides ~/.claude)

set -uo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
SRC="$REPO_DIR/statusline/statusline.sh"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST="$CONFIG_DIR/statusline.sh"
SETTINGS="$CONFIG_DIR/settings.json"
MARKER="Claude Code session status line"  # in the statusline script's header
OPENSPEC_PKG="@fission-ai/openspec@latest"
OPENSPEC_MIN_NODE="20.19.0"  # from the package's engines field
RTK_INSTALLER="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
RTK_BIN="${RTK_INSTALL_DIR:-$HOME/.local/bin}/rtk"

want_openspec=0 want_rtk=0 want_model=1
for arg in "$@"; do
  case "$arg" in
    --openspec) want_openspec=1 ;;
    --rtk) want_rtk=1 ;;
    --no-model-setting) want_model=0 ;;
    *) echo "ERROR   unknown option: $arg"; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "ERROR   jq not found. The statusline and the model setting need it. Install it with: brew install jq (macOS), sudo apt install jq (Debian/Ubuntu or WSL), winget install jqlang.jq (Windows)"; exit 1; }
[[ -f "$SRC" ]] || { echo "ERROR   $SRC not found"; exit 1; }
case "$DEST" in
  *[\"\$\`\\]*|*$'\n'*)
    echo "ERROR   $DEST contains a quote, \$, backtick, backslash or newline; the statusLine command can't quote it. Set CLAUDE_CONFIG_DIR to a plainer path"; exit 1 ;;
esac
mkdir -p "$CONFIG_DIR"
failed=0

# --- settings.json helpers ---
# Runs jq "$@" into a temp file, then copies it over $SETTINGS in place, which
# follows a symlink and keeps the mode. A new file is moved into place. A failed
# jq leaves $SETTINGS untouched.
write_settings() {
  local tmp
  tmp="$(mktemp "$SETTINGS.XXXXXX")" || return 1
  if jq "$@" > "$tmp" && [[ -s "$tmp" ]]; then
    if [[ -e "$SETTINGS" || -L "$SETTINGS" ]]; then
      cat "$tmp" > "$SETTINGS" && rm -f "$tmp" && return 0
    else
      mv "$tmp" "$SETTINGS" && return 0
    fi
  fi
  rm -f "$tmp"; echo "ERROR   could not write $SETTINGS"; return 1
}
backup_settings() {
  [[ -e "$SETTINGS.dotskills.bak" ]] || cp -p "$SETTINGS" "$SETTINGS.dotskills.bak"
}
# True if $SETTINGS exists and is a JSON object; says why not otherwise.
settings_usable() {
  if jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then return 0; fi
  echo "ERROR   $SETTINGS is not a valid JSON object; leaving it alone"; return 1
}

# --- statusline: the script ---
statusline_script() {
  if [[ -L "$DEST" && ! -e "$DEST" ]]; then
    rm "$DEST"  # dangling link, e.g. to a deleted clone; replaced below
  fi
  if [[ -L "$DEST" ]]; then
    if grep -qF "$MARKER" "$DEST"; then
      echo "ok      $DEST is a symlink to the dotskills statusline (from ./install.sh); leaving it alone"
    else
      echo "ERROR   $DEST is a symlink to $(readlink "$DEST"), not the dotskills statusline; not replacing it"; return 1
    fi
  elif [[ -e "$DEST" ]] && ! grep -qF "$MARKER" "$DEST"; then
    echo "ERROR   $DEST exists and is not the dotskills statusline; not replacing it"; return 1
  elif [[ -f "$DEST" ]] && cmp -s "$SRC" "$DEST"; then
    echo "ok      $DEST is up to date"
  else
    local verb
    [[ -e "$DEST" ]] && verb="updated" || verb="copied "
    cp "$SRC" "$DEST" && chmod +x "$DEST" || { echo "ERROR   could not write $DEST"; return 1; }
    echo "$verb $DEST"
  fi
}

# --- statusline: settings.json ---
# The command is run through a shell, so the path is double-quoted (one form for
# every path; spaces are common in Windows and macOS user names).
statusline_settings() {
  local cmd want current have
  cmd="\"$DEST\""
  want="$(jq -cn --arg c "$cmd" '{type: "command", command: $c, timeout: 10}')"
  if [[ ! -e "$SETTINGS" ]]; then
    write_settings -n --argjson v "$want" '{statusLine: $v}' || return 1
    echo "added   statusLine to $SETTINGS (new file)"; return 0
  fi
  settings_usable || return 1
  current="$(jq -c '.statusLine // empty' "$SETTINGS")"
  # Recognised by its command alone: Claude Code drops `timeout` when it rewrites
  # settings.json (e.g. on a plugin install). Older versions wrote the bare path;
  # that is ours too, and gets quoted.
  have="$(jq -r '.statusLine.command? // empty' "$SETTINGS")"
  if [[ "$have" == "$cmd" ]]; then
    echo "ok      statusLine in $SETTINGS"; return 0
  fi
  if [[ "$have" != "$DEST" && -n "$current" ]]; then
    echo "skip    statusLine: $SETTINGS already sets $current; not overwriting (remove it first to use this one)"; return 0
  fi
  backup_settings
  if [[ "$have" == "$DEST" ]]; then
    write_settings --arg c "$cmd" '.statusLine.command = $c' "$SETTINGS" || return 1
    echo "updated statusLine in $SETTINGS (quoted the command path; backup: $SETTINGS.dotskills.bak)"; return 0
  fi
  write_settings --argjson v "$want" '.statusLine = $v' "$SETTINGS" || return 1
  echo "added   statusLine to $SETTINGS (backup: $SETTINGS.dotskills.bak)"
}

# --- model ---
# Sets "model": "sonnet" unless a model is already set. Never undone: it can't be told
# apart from a model the user chose.
model_setting() {
  local current
  if [[ ! -e "$SETTINGS" ]]; then
    write_settings -n '{model: "sonnet"}' || return 1
    echo "added   model to $SETTINGS (new file)"; return 0
  fi
  settings_usable || return 1
  current="$(jq -c '.model // empty' "$SETTINGS")"
  if [[ "$current" == '"sonnet"' ]]; then echo "ok      model in $SETTINGS"; return 0; fi
  if [[ -n "$current" ]]; then echo "skip    model: $SETTINGS already sets $current"; return 0; fi
  backup_settings
  write_settings '.model = "sonnet"' "$SETTINGS" || return 1
  echo "added   model to $SETTINGS (backup: $SETTINGS.dotskills.bak)"
}

# --- openspec ---
# True if version $1 >= version $2 (both MAJOR.MINOR.PATCH, optional leading v).
version_ge() {
  local -a a b
  local i
  IFS=. read -r -a a <<<"${1#v}"
  IFS=. read -r -a b <<<"${2#v}"
  for i in 0 1 2; do
    (( ${a[i]:-0} > ${b[i]:-0} )) && return 0
    (( ${a[i]:-0} < ${b[i]:-0} )) && return 1
  done
  return 0
}

openspec_setup() {
  local node_version
  if command -v openspec >/dev/null 2>&1; then
    echo "ok      openspec $(openspec --version 2>/dev/null || echo '(version unknown)')"; return 0
  fi
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "WARN    openspec: Node.js/npm not found; install Node.js $OPENSPEC_MIN_NODE or newer, then run: npm install -g $OPENSPEC_PKG"; return 1
  fi
  node_version="$(node --version)"
  if ! version_ge "$node_version" "$OPENSPEC_MIN_NODE"; then
    echo "WARN    openspec: Node.js $node_version is too old; OpenSpec needs $OPENSPEC_MIN_NODE or newer, then run: npm install -g $OPENSPEC_PKG"; return 1
  fi
  if npm install -g "$OPENSPEC_PKG"; then
    echo "installed openspec $(openspec --version 2>/dev/null || true)"
  else
    echo "WARN    openspec: npm install failed (a permissions error usually means npm's global prefix needs sudo or a user-owned prefix)"; return 1
  fi
}

# --- rtk ---
rtk_setup() {
  local rtk
  rtk="$(command -v rtk 2>/dev/null || true)"
  [[ -z "$rtk" && -x "$RTK_BIN" ]] && rtk="$RTK_BIN"
  if [[ -n "$rtk" ]]; then
    # A different crate is also called rtk; only the right one has `gain`.
    if ! "$rtk" gain >/dev/null 2>&1; then
      echo "WARN    rtk: $rtk is not rtk-ai/rtk (\`rtk gain\` failed); skipping"; return 1
    fi
    echo "ok      rtk $("$rtk" --version 2>/dev/null | sed "s/^rtk //")"
  else
    if ! command -v curl >/dev/null 2>&1; then
      echo "WARN    rtk: curl not found; install curl and rerun, or see https://github.com/rtk-ai/rtk"; return 1
    fi
    if ! curl -fsSL "$RTK_INSTALLER" | sh; then
      echo "WARN    rtk: install script failed"; return 1
    fi
    rtk="$RTK_BIN"
    echo "installed rtk $("$rtk" --version 2>/dev/null | sed "s/^rtk //")"
    command -v rtk >/dev/null 2>&1 || echo "note    add $(dirname "$RTK_BIN") to your PATH so Claude Code's hook can find rtk"
  fi
  # `rtk init -g` writes the hook to settings.json and can ask its own questions,
  # so the user runs it, not this script.
  if [[ -f "$SETTINGS" ]] && grep -q rtk "$SETTINGS"; then
    echo "ok      rtk hook in $SETTINGS"
  else
    echo "note    rtk hook not set up; the user runs: rtk init -g"
  fi
}

statusline_script && statusline_settings || failed=1
if [[ $want_model -eq 1 ]]; then model_setting || failed=1; fi
if [[ $want_openspec -eq 1 ]]; then openspec_setup || failed=1; fi
if [[ $want_rtk -eq 1 ]]; then rtk_setup || failed=1; fi
exit $failed
