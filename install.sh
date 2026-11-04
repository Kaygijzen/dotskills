#!/usr/bin/env bash
# Symlinks skills (skills/<domain>/<name>/) into ~/.claude/skills/<name> and
# subagents (agents/<domain>/<name>.md) into ~/.claude/agents/<name>.md, and the
# statusline script (statusline/statusline.sh) to ~/.claude/statusline.sh, so
# edits in this repo are live in Claude Code immediately.
#
# Usage:
#   ./install.sh                       link every domain's skills and agents (safe to rerun)
#   ./install.sh --domain NAME         only core plus the named domain(s); repeatable
#   ./install.sh --all                 every domain (the default; explicit form)
#   ./install.sh NAME [NAME ...]       link only the named skills or agents
#   ./install.sh --conventions         add the managed import block to ~/.claude/CLAUDE.md
#   ./install.sh --init-project PATH   copy conventions/project-template/ into PATH (never overwrites)
#   ./install.sh --uninstall [NAME..]  remove only what this script created (links, conventions block)
#   ./install.sh --check               validate the repo (same as scripts/validate.sh)
#   ./install.sh --target codex        not implemented yet; prints a note and exits 0
#   ./install.sh --statusline-settings set `statusLine` in settings.json (the only key this script edits)
#   ./install.sh --with-openspec       also install the OpenSpec CLI without asking
#   ./install.sh --no-openspec         never ask about the OpenSpec CLI
#   ./install.sh --with-rtk            also install rtk and run `rtk init -g` without asking
#   ./install.sh --no-rtk              never ask about rtk
#
# CLAUDE_SKILLS_DIR / CLAUDE_AGENTS_DIR / CLAUDE_CONFIG_DIR override ~/.claude/skills,
# ~/.claude/agents and ~/.claude. Existing folders or foreign symlinks with the same
# name are never touched. Hooks and MCP servers ship through the plugin only; this
# script edits settings.json only with --statusline-settings, and then only the
# `statusLine` key (backed up first, never overwriting a different statusLine). On Windows, use install.ps1 instead.
# If the openspec CLI (needed by grill-spec) is missing, install asks whether to
# install it with npm; likewise for rtk (token-saving Bash hook), installed with
# its official script. Without a terminal to ask on, both only print a hint.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="$REPO_DIR/skills"
AGENTS_SRC="$REPO_DIR/agents"
STATUSLINE_SRC="$REPO_DIR/statusline/statusline.sh"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$CONFIG_DIR/skills}"
AGENTS_DEST="${CLAUDE_AGENTS_DIR:-$CONFIG_DIR/agents}"
STATUSLINE_DEST="$CONFIG_DIR/statusline.sh"
CLAUDE_SETTINGS="$CONFIG_DIR/settings.json"
MEMORY_FILE="$CONFIG_DIR/CLAUDE.md"
BLOCK_START="# >>> dotskills conventions >>>"
BLOCK_END="# <<< dotskills conventions <<<"

usage() {
  sed -n '2,30s/^# \{0,1\}//p' "$0"
}

# True if $1 is a symlink this script created, i.e. it points into this repo's
# skills/ or agents/ folder.
is_ours() {
  [[ -L "$1" ]] || return 1
  local t
  t="$(readlink "$1")"
  [[ "$t" == "$SRC_DIR/"* || "$t" == "$AGENTS_SRC/"* || "$t" == "$STATUSLINE_SRC" ]]
}

# Prints the source path of skill/agent $2 (kind $1: skill|agent), or fails.
find_item() {
  local kind="$1" name="$2" d
  if [[ "$kind" == skill ]]; then
    for d in "$SRC_DIR"/*/"$name"; do
      [[ -f "$d/SKILL.md" ]] && { echo "$d"; return 0; }
    done
  else
    for d in "$AGENTS_SRC"/*/"$name.md"; do
      [[ -f "$d" ]] && { echo "$d"; return 0; }
    done
  fi
  return 1
}

# $1 kind, $2 name, $3 src, $4 dest. Prints one status line; returns 1 if skipped.
link_one() {
  local kind="$1" name="$2" src="$3" dest="$4"

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      echo "ok      $name"
      return 0
    fi
    if is_ours "$dest"; then
      ln -sfn "$src" "$dest"
      echo "relink  $name"
      return 0
    fi
    echo "WARN    $name: $dest is a symlink to $(readlink "$dest"), not this repo; skipping"
    return 1
  fi

  if [[ -e "$dest" ]]; then
    echo "WARN    $name: $dest already exists and is not a symlink; skipping"
    return 1
  fi

  ln -s "$src" "$dest"
  echo "linked  $name${kind:+ ($kind)}"
}

# Lists "kind name src" for every skill and agent in the given domains
# (all domains when none are given).
list_items() {
  local dir file domain
  local -a domains=("$@")
  in_domains() {
    local x
    [[ ${#domains[@]} -eq 0 ]] && return 0
    for x in "${domains[@]}"; do [[ "$x" == "$1" ]] && return 0; done
    return 1
  }
  for dir in "$SRC_DIR"/*/*/; do
    [[ -f "$dir/SKILL.md" ]] || continue
    dir="${dir%/}"
    domain="$(basename "$(dirname "$dir")")"
    in_domains "$domain" && echo "skill $(basename "$dir") $dir"
  done
  for file in "$AGENTS_SRC"/*/*.md; do
    [[ -f "$file" ]] || continue
    domain="$(basename "$(dirname "$file")")"
    in_domains "$domain" && echo "agent $(basename "$file" .md) $file"
  done
  return 0
}

# Removes symlinks into this repo whose target no longer exists.
prune_stale() {
  local link
  for link in "$DEST_DIR"/* "$AGENTS_DEST"/*; do
    if is_ours "$link" && [[ ! -e "$link" ]]; then
      rm "$link"
      echo "pruned  $(basename "$link") (no longer in repo)"
    fi
  done
}

# Args: names to link (skills or agents). With none, links every item in the
# domains listed in the DOMAINS array.
install() {
  local failed=0 name kind src found
  mkdir -p "$DEST_DIR"
  [[ -d "$AGENTS_SRC" ]] && mkdir -p "$AGENTS_DEST"

  if [[ $# -gt 0 ]]; then
    for name in "$@"; do
      found=0
      if src="$(find_item skill "$name")"; then
        found=1; link_one skill "$name" "$src" "$DEST_DIR/$name" || failed=1
      fi
      if src="$(find_item agent "$name")"; then
        found=1; link_one agent "$name" "$src" "$AGENTS_DEST/$name.md" || failed=1
      fi
      if [[ $found -eq 0 ]]; then
        echo "skip    $name: no skill or agent with this name"; failed=1
      fi
    done
  else
    while read -r kind name src; do
      if [[ "$kind" == skill ]]; then
        link_one "" "$name" "$src" "$DEST_DIR/$name" || failed=1
      else
        link_one agent "$name" "$src" "$AGENTS_DEST/$name.md" || failed=1
      fi
    done < <(list_items ${DOMAINS[@]+"${DOMAINS[@]}"})
    prune_stale
    if [[ -f "$STATUSLINE_SRC" ]]; then
      mkdir -p "$CONFIG_DIR"
      link_one statusline statusline "$STATUSLINE_SRC" "$STATUSLINE_DEST" || failed=1
    fi
  fi

  echo
  echo "Skills directory: $DEST_DIR"
  echo "Agents directory: $AGENTS_DEST"
  return $failed
}

# --- jq check and next steps ----------------------------------------------

# Warns (never fails) when jq is missing. Linking doesn't need it.
check_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  echo "WARN    jq not found. The statusline, the .env secret hook and --statusline-settings need it. Install it with: brew install jq (macOS), sudo apt install jq (Debian/Ubuntu or WSL)"
}

# Printed after a full install run. Suggests --conventions only when the block is missing.
print_next_steps() {
  echo
  echo "Next steps:"
  echo "  - Restart Claude Code if it is running."
  echo "  - Run /hello-skill to check the install."
  has_block || echo "  - Run ./install.sh --conventions to add the conventions block to $MEMORY_FILE."
  echo "  - Hooks, including the .env secret blocker, ship only with the plugin install."
}

# --- conventions: a managed block in ~/.claude/CLAUDE.md ------------------

conventions_block() {
  printf '%s\n' "$BLOCK_START" "# Managed by dotskills ./install.sh; edit conventions/AGENTS.md in the repo instead." "@${REPO_DIR// /\\ }/conventions/AGENTS.md" "$BLOCK_END"
}

has_block() {
  [[ -f "$MEMORY_FILE" ]] && grep -qxF "$BLOCK_START" "$MEMORY_FILE"
}

# Removes the managed block and the one blank separator line install_conventions
# put before it. Everything else in $MEMORY_FILE is left byte-for-byte alone.
strip_block() {
  local tmp
  tmp="$(mktemp)"
  awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
    $0 == s { skip = 1; held_blank = 0; next }
    skip    { if ($0 == e) skip = 0; next }
    { if (held_blank) print ""; held_blank = 0
      if ($0 == "") { held_blank = 1 } else { print } }
    END { if (held_blank) print "" }
  ' "$MEMORY_FILE" > "$tmp"
  cat "$tmp" > "$MEMORY_FILE"
  rm -f "$tmp"
}

install_conventions() {
  if [[ ! -f "$REPO_DIR/conventions/AGENTS.md" ]]; then
    echo "skip    conventions: $REPO_DIR/conventions/AGENTS.md not found"
    return 1
  fi
  mkdir -p "$CONFIG_DIR"
  if has_block; then
    if [[ "$(awk -v s="$BLOCK_START" -v e="$BLOCK_END" '$0==s{f=1} f{print} $0==e{exit}' "$MEMORY_FILE")" == "$(conventions_block)" ]]; then
      echo "ok      conventions block in $MEMORY_FILE"
      return 0
    fi
    strip_block
    echo "update  conventions block in $MEMORY_FILE"
  else
    echo "added   conventions block to $MEMORY_FILE"
  fi
  if [[ -s "$MEMORY_FILE" ]]; then printf '\n' >> "$MEMORY_FILE"; fi
  conventions_block >> "$MEMORY_FILE"
}

uninstall_conventions() {
  has_block || { echo "skip    conventions: no managed block in $MEMORY_FILE"; return 0; }
  strip_block
  if [[ ! -s "$MEMORY_FILE" ]]; then rm -f "$MEMORY_FILE"; echo "removed conventions block (and the now-empty $MEMORY_FILE)"
  else echo "removed conventions block from $MEMORY_FILE"; fi
}

# --- statusline: the one key we set in settings.json -----------------------

statusline_value() {
  jq -cn --arg c "$STATUSLINE_DEST" '{type: "command", command: $c, timeout: 10}'
}

# Writes stdin to $CLAUDE_SETTINGS via a temp file. The caller makes the
# one-time backup (see install_statusline).
write_settings() {
  local tmp
  tmp="$(mktemp "$CLAUDE_SETTINGS.XXXXXX")" || return 1
  cat > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS" || { rm -f "$tmp"; return 1; }
}

install_statusline_settings() {
  local current want
  want="$(statusline_value)"
  if [[ ! -f "$STATUSLINE_SRC" ]]; then
    echo "skip    statusLine: $STATUSLINE_SRC not found"; return 1
  fi
  link_one statusline statusline "$STATUSLINE_SRC" "$STATUSLINE_DEST" || return 1
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    jq -n --argjson v "$want" '{statusLine: $v}' | write_settings || return 1
    echo "added   statusLine to $CLAUDE_SETTINGS (new file)"
    return 0
  fi
  if ! jq -e 'type == "object"' "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
    echo "WARN    statusLine: $CLAUDE_SETTINGS is not a valid JSON object; leaving it alone"; return 1
  fi
  current="$(jq -c '.statusLine // empty' "$CLAUDE_SETTINGS")"
  if [[ "$current" == "$want" ]]; then
    echo "ok      statusLine in $CLAUDE_SETTINGS"; return 0
  fi
  if [[ -n "$current" ]]; then
    echo "WARN    statusLine: $CLAUDE_SETTINGS already sets $current; not overwriting (remove it first to use this one)"
    return 1
  fi
  [[ -e "$CLAUDE_SETTINGS.dotskills.bak" ]] || cp -p "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.dotskills.bak"
  jq --argjson v "$want" '.statusLine = $v' "$CLAUDE_SETTINGS" | write_settings || return 1
  echo "added   statusLine to $CLAUDE_SETTINGS (backup: $CLAUDE_SETTINGS.dotskills.bak)"
}

# Removes statusLine only if it is still exactly what install_statusline_settings wrote.
uninstall_statusline_settings() {
  [[ -f "$CLAUDE_SETTINGS" ]] || return 0
  jq -e 'type == "object"' "$CLAUDE_SETTINGS" >/dev/null 2>&1 || return 0
  if [[ "$(jq -c '.statusLine // empty' "$CLAUDE_SETTINGS")" == "$(statusline_value)" ]]; then
    jq 'del(.statusLine)' "$CLAUDE_SETTINGS" | write_settings || return 1
    echo "removed statusLine from $CLAUDE_SETTINGS"
  fi
}

# --- init-project ---------------------------------------------------------

init_project() {
  local target="$1" tpl="$REPO_DIR/conventions/project-template" rel copied=0 skipped=0
  if [[ ! -d "$target" ]]; then
    echo "WARN    --init-project: $target is not a directory"
    return 1
  fi
  while IFS= read -r rel; do
    rel="${rel#./}"
    if [[ -e "$target/$rel" || -L "$target/$rel" ]]; then
      echo "skip    $rel (already exists)"; skipped=$((skipped + 1))
    else
      mkdir -p "$target/$(dirname "$rel")"
      cp "$tpl/$rel" "$target/$rel"
      echo "copied  $rel"; copied=$((copied + 1))
    fi
  done < <(cd "$tpl" && find . -type f | LC_ALL=C sort)
  echo
  echo "Project template: $copied copied, $skipped skipped in $target"
}

# --- codex (not implemented) ----------------------------------------------

# Where Codex support will go. Not wired up yet.
#   - Skills: link each skill whose frontmatter `targets` includes codex (the
#     default) into Codex's skills directory; skip targets: [claude] skills.
#   - Conventions: add the same import to ~/.codex/AGENTS.md (Codex reads
#     AGENTS.md natively, so conventions/AGENTS.md can be referenced directly).
#   - Subagents, hooks and MCP configs stay Claude-only for now.
install_codex() {
  echo "note    --target codex is not implemented yet; nothing was changed"
}

OPENSPEC_PKG="@fission-ai/openspec@latest"
# From the package's engines field: npm view @fission-ai/openspec engines
OPENSPEC_MIN_NODE="20.19.0"

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

# Prints why openspec can't be installed with npm here, or nothing if it can.
openspec_blocker() {
  local node_version
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "Node.js/npm not found; install Node.js $OPENSPEC_MIN_NODE or newer"
    return
  fi
  node_version="$(node --version)"
  if ! version_ge "$node_version" "$OPENSPEC_MIN_NODE"; then
    echo "Node.js $node_version is too old; OpenSpec needs $OPENSPEC_MIN_NODE or newer"
  fi
}

# $1 is ask, yes or no.
install_openspec() {
  local choice="$1" reply blocker

  if command -v openspec >/dev/null 2>&1; then
    echo "ok      openspec $(openspec --version 2>/dev/null || echo '(version unknown)')"
    return 0
  fi
  [[ "$choice" == no ]] && return 0

  # Check prerequisites before asking, so we never offer an install that can't work.
  # Only a run that explicitly asked for openspec (--with-openspec) fails on this.
  blocker="$(openspec_blocker)"
  if [[ -n "$blocker" ]]; then
    echo "WARN    openspec not found (grill-spec needs it): $blocker, then run: npm install -g $OPENSPEC_PKG"
    [[ "$choice" == yes ]] && return 1
    return 0
  fi

  if [[ "$choice" == ask ]]; then
    if [[ ! -t 0 ]]; then
      echo "note    openspec not found; grill-spec needs it. Rerun with --with-openspec or run: npm install -g $OPENSPEC_PKG"
      return 0
    fi
    read -r -p "OpenSpec CLI not found (grill-spec needs it). Install with npm now? [y/N] " reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || { echo "skip    openspec"; return 0; }
  fi

  if npm install -g "$OPENSPEC_PKG"; then
    echo "installed openspec $(openspec --version 2>/dev/null || true)"
  else
    echo "WARN    openspec: npm install failed (a permissions error usually means npm's global prefix needs sudo or a user-owned prefix)"
    return 1
  fi
}

RTK_INSTALLER="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
RTK_BIN="${RTK_INSTALL_DIR:-$HOME/.local/bin}/rtk"

# $1 is the question. True on yes; false on no or when there's no terminal.
confirm() {
  local reply
  [[ -t 0 ]] || return 1
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# $1 is ask, yes or no.
install_rtk() {
  local choice="$1" rtk

  [[ "$choice" == no ]] && return 0
  rtk="$(command -v rtk 2>/dev/null || true)"
  [[ -z "$rtk" && -x "$RTK_BIN" ]] && rtk="$RTK_BIN"

  if [[ -n "$rtk" ]]; then
    # A different crate is also called rtk; only the right one has `gain`.
    if ! "$rtk" gain >/dev/null 2>&1; then
      echo "WARN    rtk: $rtk is not rtk-ai/rtk (\`rtk gain\` failed); skipping"
      return 1
    fi
    echo "ok      rtk $("$rtk" --version 2>/dev/null | sed "s/^rtk //")"
  else
    if [[ "$choice" == ask ]]; then
      if [[ ! -t 0 ]]; then
        echo "note    rtk not found (optional, saves tokens on Bash output). Rerun with --with-rtk or see https://github.com/rtk-ai/rtk"
        return 0
      fi
      confirm "rtk not found (optional, saves tokens on Bash output). Install it now?" || { echo "skip    rtk"; return 0; }
    fi
    if ! command -v curl >/dev/null 2>&1; then
      echo "WARN    rtk: curl not found; install curl, then rerun with --with-rtk"
      return 1
    fi
    if ! curl -fsSL "$RTK_INSTALLER" | sh; then
      echo "WARN    rtk: install script failed"
      return 1
    fi
    rtk="$RTK_BIN"
    echo "installed rtk $("$rtk" --version 2>/dev/null | sed "s/^rtk //")"
    command -v rtk >/dev/null 2>&1 || echo "note    add $(dirname "$RTK_BIN") to your PATH so Claude Code's hook can find rtk"
  fi

  # Rough check for an existing hook; `rtk init -g` writes it to settings.json.
  if [[ -f "$CLAUDE_SETTINGS" ]] && grep -q rtk "$CLAUDE_SETTINGS"; then
    echo "ok      rtk hook in $CLAUDE_SETTINGS"
    return 0
  fi
  # `rtk init -g` can ask its own questions, so it only runs with a terminal.
  if [[ ! -t 0 ]]; then
    echo "note    rtk hook not set up; run: rtk init -g"
    return 0
  fi
  if [[ "$choice" == yes ]] || confirm "Run \`rtk init -g\` to add rtk's hook to your Claude Code settings?"; then
    "$rtk" init -g || { echo "WARN    rtk: \`rtk init -g\` failed"; return 1; }
    echo "note    restart Claude Code to load the rtk hook"
  else
    echo "skip    rtk init (run \`rtk init -g\` later)"
  fi
}

uninstall() {
  local name link removed=0
  if [[ $# -gt 0 ]]; then
    for name in "$@"; do
      local any=0
      local -a links=("$DEST_DIR/$name" "$AGENTS_DEST/$name.md")
      if [[ "$name" == statusline ]]; then
        links+=("$STATUSLINE_DEST")
        uninstall_statusline_settings
      fi
      for link in "${links[@]}"; do
        if is_ours "$link"; then
          rm "$link"; echo "removed $name"; removed=$((removed + 1)); any=1
        elif [[ -e "$link" || -L "$link" ]]; then
          echo "WARN    $name: $link was not created by this script; leaving it"; any=1
        fi
      done
      [[ $any -eq 1 ]] || echo "skip    $name: not installed"
    done
  else
    for link in "$DEST_DIR"/* "$AGENTS_DEST"/* "$STATUSLINE_DEST"; do
      if is_ours "$link"; then
        rm "$link"; echo "removed $(basename "$link")"; removed=$((removed + 1))
      fi
    done
    uninstall_conventions
    uninstall_statusline_settings
  fi

  echo
  echo "Removed $removed symlink(s)"
}

main() {
  local mode=install openspec=ask rtk=ask conventions=0 sl_settings=0 init_path="" target=claude
  local -a names=()
  DOMAINS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall) mode=uninstall ;;
      --check)     mode=check ;;
      --all)       DOMAINS=() ;;
      --domain)    shift; [[ $# -gt 0 ]] || { echo "--domain needs a name" >&2; return 2; }
                   DOMAINS+=("$1") ;;
      --conventions) conventions=1 ;;
      --statusline-settings) sl_settings=1 ;;
      --init-project) shift; [[ $# -gt 0 ]] || { echo "--init-project needs a path" >&2; return 2; }
                   mode=init; init_path="$1" ;;
      --target)    shift; [[ $# -gt 0 ]] || { echo "--target needs claude or codex" >&2; return 2; }
                   target="$1" ;;
      --with-openspec) openspec=yes ;;
      --no-openspec)   openspec=no ;;
      --with-rtk)      rtk=yes ;;
      --no-rtk)        rtk=no ;;
      -h|--help)   usage; return 0 ;;
      -*)          echo "Unknown option: $1" >&2; usage >&2; return 2 ;;
      *)           names+=("${1%/}") ;;
    esac
    shift
  done

  if [[ "$target" == codex ]]; then install_codex; return 0; fi
  [[ "$target" == claude ]] || { echo "Unknown target: $target (use claude or codex)" >&2; return 2; }

  if [[ ${#DOMAINS[@]} -gt 0 ]]; then
    local d
    for d in "${DOMAINS[@]}"; do
      if [[ ! -d "$SRC_DIR/$d" && ! -d "$AGENTS_SRC/$d" ]]; then
        echo "Unknown domain: $d (have: $(cd "$SRC_DIR" && ls | tr '\n' ' '))" >&2
        return 2
      fi
    done
    DOMAINS=(core "${DOMAINS[@]}")
  fi

  case "$mode" in
    install)
      local failed=0 linked=0
      check_jq
      # With only --conventions, skip linking.
      if [[ ( $conventions -eq 0 && $sl_settings -eq 0 ) || ${#names[@]} -gt 0 || ${#DOMAINS[@]} -gt 0 ]]; then
        install ${names[@]+"${names[@]}"} || failed=1
        install_openspec "$openspec" || failed=1
        install_rtk "$rtk" || failed=1
        linked=1
      fi
      if [[ $conventions -eq 1 ]]; then install_conventions || failed=1; fi
      if [[ $sl_settings -eq 1 ]]; then install_statusline_settings || failed=1; fi
      if [[ $linked -eq 1 ]]; then print_next_steps; fi
      return $failed
      ;;
    uninstall) uninstall ${names[@]+"${names[@]}"} ;;
    check)     "$REPO_DIR/scripts/validate.sh" ${names[@]+"${names[@]}"} ;;
    init)      init_project "$init_path" ;;
  esac
}

main "$@"
