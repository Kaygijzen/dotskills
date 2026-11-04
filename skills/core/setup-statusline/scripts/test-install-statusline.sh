#!/usr/bin/env bash
# Tests install-statusline.sh. Usage: skills/core/setup-statusline/scripts/test-install-statusline.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT="$DIR/install-statusline.sh"
SRC="$(cd "$DIR/../../../.." && pwd -P)/statusline/statusline.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

run() { CLAUDE_CONFIG_DIR="$tmp/c" "$SCRIPT" >"$tmp/out" 2>&1; echo $?; }
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1: $(cat "$tmp/out")"; fail=1; }
sl()  { jq -c '.statusLine // empty' "$tmp/c/settings.json"; }
want="$(jq -cn --arg c "\"$tmp/c/statusline.sh\"" '{type: "command", command: $c, timeout: 10}')"
# File mode, portable across GNU and BSD.
mode() { ls -lL "$1" | cut -c1-10; }

# Fresh config: copies the script and creates settings.json.
rm -rf "$tmp/c"
[[ "$(run)" == 0 ]] && cmp -s "$SRC" "$tmp/c/statusline.sh" && [[ -x "$tmp/c/statusline.sh" && "$(sl)" == "$want" ]] && ok "fresh install" || bad "fresh install"

# Second run changes nothing.
[[ "$(run)" == 0 ]] && grep -q "is up to date" "$tmp/out" && grep -q "^ok      statusLine" "$tmp/out" && ok "rerun is a no-op" || bad "rerun is a no-op"

# Outdated copy gets refreshed.
echo "# old" >> "$tmp/c/statusline.sh"
[[ "$(run)" == 0 ]] && cmp -s "$SRC" "$tmp/c/statusline.sh" && ok "refreshes an old copy" || bad "refreshes an old copy"

# Existing settings keep their keys and get a backup.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; echo '{"model":"sonnet"}' > "$tmp/c/settings.json"
[[ "$(run)" == 0 ]] && [[ "$(jq -r .model "$tmp/c/settings.json")" == sonnet && "$(sl)" == "$want" && -f "$tmp/c/settings.json.dotskills.bak" ]] && ok "merges into settings with backup" || bad "merges into settings with backup"

# A different statusLine is left alone.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; echo '{"statusLine":{"type":"command","command":"mine.sh"}}' > "$tmp/c/settings.json"
[[ "$(run)" == 1 ]] && [[ "$(jq -r .statusLine.command "$tmp/c/settings.json")" == mine.sh ]] && ok "keeps a different statusLine" || bad "keeps a different statusLine"

# Someone else's statusline.sh is not replaced.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; echo 'echo mine' > "$tmp/c/statusline.sh"
[[ "$(run)" == 1 ]] && [[ "$(cat "$tmp/c/statusline.sh")" == "echo mine" ]] && ok "keeps a foreign statusline.sh" || bad "keeps a foreign statusline.sh"

# A symlink from ./install.sh is left alone.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; ln -s "$SRC" "$tmp/c/statusline.sh"
[[ "$(run)" == 0 ]] && [[ -L "$tmp/c/statusline.sh" ]] && ok "keeps an install.sh symlink" || bad "keeps an install.sh symlink"

# Invalid settings.json is left alone.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; echo 'not json' > "$tmp/c/settings.json"
[[ "$(run)" == 1 ]] && [[ "$(cat "$tmp/c/settings.json")" == "not json" ]] && ok "keeps invalid settings.json" || bad "keeps invalid settings.json"

# Run through a symlinked skill dir, as ./install.sh links it to ~/.claude/skills/.
rm -rf "$tmp/c"; mkdir -p "$tmp/h/skills"; ln -s "$(dirname "$DIR")" "$tmp/h/skills/setup-statusline"
CLAUDE_CONFIG_DIR="$tmp/c" "$tmp/h/skills/setup-statusline/scripts/install-statusline.sh" >"$tmp/out" 2>&1 \
  && cmp -s "$SRC" "$tmp/c/statusline.sh" && ok "works through a symlinked skill dir" || bad "works through a symlinked skill dir"

# A dangling symlink (clone deleted without --uninstall) is replaced by a copy.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; ln -s /nonexistent/statusline.sh "$tmp/c/statusline.sh"
[[ "$(run)" == 0 ]] && [[ ! -L "$tmp/c/statusline.sh" ]] && cmp -s "$SRC" "$tmp/c/statusline.sh" && ok "replaces a dangling symlink" || bad "replaces a dangling symlink"

# A symlink to someone else's script is not adopted.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; echo 'echo mine' > "$tmp/mine.sh"; ln -s "$tmp/mine.sh" "$tmp/c/statusline.sh"
[[ "$(run)" == 1 ]] && [[ "$(readlink "$tmp/c/statusline.sh")" == "$tmp/mine.sh" && ! -f "$tmp/c/settings.json" ]] && ok "keeps a foreign symlink" || bad "keeps a foreign symlink"

# An existing backup is not overwritten.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; echo '{"a":1}' > "$tmp/c/settings.json"; echo 'first' > "$tmp/c/settings.json.dotskills.bak"
[[ "$(run)" == 0 ]] && [[ "$(cat "$tmp/c/settings.json.dotskills.bak")" == first ]] && ok "keeps an existing backup" || bad "keeps an existing backup"

# Without jq nothing is written.
rm -rf "$tmp/c"
CLAUDE_CONFIG_DIR="$tmp/c" PATH=/nonexistent /bin/bash "$SCRIPT" >"$tmp/out" 2>&1; rc=$?
[[ $rc -eq 1 && ! -e "$tmp/c" ]] && grep -q "jq not found" "$tmp/out" && ok "stops without jq" || bad "stops without jq"

# A symlinked settings.json (dotfiles repo) stays a link; its target is updated and keeps its mode.
rm -rf "$tmp/c" "$tmp/dot"; mkdir -p "$tmp/c" "$tmp/dot"; echo '{"model":"sonnet"}' > "$tmp/dot/settings.json"
chmod 644 "$tmp/dot/settings.json"; ln -s "$tmp/dot/settings.json" "$tmp/c/settings.json"
[[ "$(run)" == 0 ]] && [[ -L "$tmp/c/settings.json" && "$(jq -c .statusLine "$tmp/dot/settings.json")" == "$want" \
  && "$(mode "$tmp/dot/settings.json")" == "-rw-r--r--" && ! -L "$tmp/c/settings.json.dotskills.bak" \
  && "$(cat "$tmp/c/settings.json.dotskills.bak")" == '{"model":"sonnet"}' ]] && ok "writes through a symlinked settings.json" || bad "writes through a symlinked settings.json"

# A failed jq write leaves settings.json as it was (a jq that reads fine but fails on write).
rm -rf "$tmp/c" "$tmp/fakebin"; mkdir -p "$tmp/c" "$tmp/fakebin"; echo '{"model":"sonnet"}' > "$tmp/c/settings.json"
realjq="$(command -v jq)"
printf '#!/bin/sh\nfor a; do [ "$a" = ".statusLine = \\$v" ] && exit 5; done\nexec "%s" "$@"\n' "$realjq" > "$tmp/fakebin/jq"; chmod +x "$tmp/fakebin/jq"
CLAUDE_CONFIG_DIR="$tmp/c" PATH="$tmp/fakebin:$PATH" "$SCRIPT" >"$tmp/out" 2>&1; rc=$?
[[ $rc -eq 1 && "$(cat "$tmp/c/settings.json")" == '{"model":"sonnet"}' ]] && grep -q "could not write" "$tmp/out" \
  && [[ -z "$(find "$tmp/c" -name 'settings.json.??????')" ]] && ok "failed write keeps settings.json" || bad "failed write keeps settings.json"

# A config dir with a space: the command is quoted and runs through a shell.
sp="$tmp/with space/c"; rm -rf "$tmp/with space"
CLAUDE_CONFIG_DIR="$sp" "$SCRIPT" >"$tmp/out" 2>&1 \
  && [[ "$(jq -r .statusLine.command "$sp/settings.json")" == "\"$sp/statusline.sh\"" ]] \
  && echo '{}' | sh -c "$(jq -r .statusLine.command "$sp/settings.json")" >/dev/null 2>&1 \
  && ok "quotes a command path with a space" || bad "quotes a command path with a space"

# A path the quotes can't protect is refused before anything is written.
rm -rf "$tmp/c\$x"
CLAUDE_CONFIG_DIR="$tmp/c\$x" "$SCRIPT" >"$tmp/out" 2>&1; rc=$?
[[ $rc -eq 1 && ! -e "$tmp/c\$x" ]] && grep -q "can't quote it" "$tmp/out" && ok "refuses an unquotable path" || bad "refuses an unquotable path"

# The bare path older versions wrote is ours: a rerun quotes it, keeping other keys.
old="$(jq -cn --arg c "$tmp/c/statusline.sh" '{type: "command", command: $c}')"
rm -rf "$tmp/c"; run >/dev/null; jq --argjson v "$old" '.statusLine = $v' "$tmp/c/settings.json" > "$tmp/s" && cp "$tmp/s" "$tmp/c/settings.json"
[[ "$(run)" == 0 ]] && grep -q "^updated statusLine" "$tmp/out" \
  && [[ "$(sl)" == "$(jq -cn --arg c "\"$tmp/c/statusline.sh\"" '{type: "command", command: $c}')" ]] \
  && ok "quotes an old unquoted statusLine" || bad "quotes an old unquoted statusLine"

# install.sh treats the skill's copy as its own: a full install swaps it for a
# link, and --uninstall removes the link and the statusLine.
REPO="$(cd "$DIR/../../../.." && pwd -P)"
installer() { CLAUDE_CONFIG_DIR="$tmp/c" CLAUDE_SKILLS_DIR="$tmp/c/skills" CLAUDE_AGENTS_DIR="$tmp/c/agents" "$REPO/install.sh" --no-openspec --no-rtk "$@" >"$tmp/out" 2>&1; }
rm -rf "$tmp/c"; run >/dev/null
installer && [[ -L "$tmp/c/statusline.sh" ]] && grep -q "relink  statusline (replaced a copy)" "$tmp/out" && ok "install.sh replaces the copy with a link" || bad "install.sh replaces the copy with a link"
rm -rf "$tmp/c"; run >/dev/null
installer --uninstall statusline && [[ ! -e "$tmp/c/statusline.sh" && -z "$(sl)" ]] && ok "install.sh --uninstall statusline removes the copy" || bad "install.sh --uninstall statusline removes the copy"
rm -rf "$tmp/c"; run >/dev/null
installer --uninstall && [[ ! -e "$tmp/c/statusline.sh" && -z "$(sl)" ]] && ok "install.sh --uninstall removes the copy" || bad "install.sh --uninstall removes the copy"
# Claude Code drops `timeout` when it rewrites settings.json; ours is still recognised.
rm -rf "$tmp/c"; run >/dev/null; jq '.statusLine |= del(.timeout)' "$tmp/c/settings.json" > "$tmp/s" && cp "$tmp/s" "$tmp/c/settings.json"
[[ "$(run)" == 0 ]] && grep -q "^ok      statusLine" "$tmp/out" && ok "recognises statusLine without timeout" || bad "recognises statusLine without timeout"
installer --uninstall && [[ -z "$(sl)" ]] && ok "install.sh --uninstall removes statusLine without timeout" || bad "install.sh --uninstall removes statusLine without timeout"
# install.sh recognises the old unquoted command too: --uninstall removes it,
# --statusline-settings quotes it.
rm -rf "$tmp/c"; run >/dev/null; jq --argjson v "$old" '.statusLine = $v' "$tmp/c/settings.json" > "$tmp/s" && cp "$tmp/s" "$tmp/c/settings.json"
installer --uninstall && [[ -z "$(sl)" ]] && ok "install.sh --uninstall removes an old unquoted statusLine" || bad "install.sh --uninstall removes an old unquoted statusLine"
rm -rf "$tmp/c"; run >/dev/null; jq --argjson v "$old" '.statusLine = $v' "$tmp/c/settings.json" > "$tmp/s" && cp "$tmp/s" "$tmp/c/settings.json"
installer --statusline-settings && grep -q "^updated statusLine" "$tmp/out" && [[ "$(jq -r .statusLine.command "$tmp/c/settings.json")" == "\"$tmp/c/statusline.sh\"" ]] \
  && ok "install.sh --statusline-settings quotes an old unquoted statusLine" || bad "install.sh --statusline-settings quotes an old unquoted statusLine"
# install.sh writes the same value as the skill, through a symlinked settings.json.
rm -rf "$tmp/c" "$tmp/dot"; mkdir -p "$tmp/c" "$tmp/dot"; echo '{}' > "$tmp/dot/settings.json"; chmod 644 "$tmp/dot/settings.json"
ln -s "$tmp/dot/settings.json" "$tmp/c/settings.json"
installer --statusline-settings && [[ -L "$tmp/c/settings.json" && "$(jq -c .statusLine "$tmp/dot/settings.json")" == "$want" && "$(mode "$tmp/dot/settings.json")" == "-rw-r--r--" ]] \
  && ok "install.sh --statusline-settings writes through a symlinked settings.json" || bad "install.sh --statusline-settings writes through a symlinked settings.json"
installer --uninstall statusline && [[ -L "$tmp/c/settings.json" && -z "$(jq -c '.statusLine // empty' "$tmp/dot/settings.json")" ]] \
  && ok "install.sh --uninstall keeps a symlinked settings.json" || bad "install.sh --uninstall keeps a symlinked settings.json"
# ...but still leaves a foreign regular file alone.
rm -rf "$tmp/c"; mkdir -p "$tmp/c"; echo 'echo mine' > "$tmp/c/statusline.sh"
installer --uninstall statusline; [[ -f "$tmp/c/statusline.sh" ]] && ok "install.sh --uninstall keeps a foreign file" || bad "install.sh --uninstall keeps a foreign file"

[[ $fail -eq 0 ]] && echo "All install-statusline tests passed." || { echo "install-statusline tests failed."; exit 1; }
