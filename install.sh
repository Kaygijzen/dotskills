#!/usr/bin/env bash
# Symlinks each skills/<name>/ folder into ~/.claude/skills/<name> so edits in
# this repo are live in Claude Code immediately.
#
# Usage:
#   ./install.sh                  link every skill (safe to rerun)
#   ./install.sh NAME [NAME ...]  link only the named skills
#   ./install.sh --uninstall      remove every symlink that points into this repo
#   ./install.sh --uninstall NAME remove only the named skills' symlinks
#   ./install.sh --check          validate every SKILL.md (same as scripts/validate.sh)
#   ./install.sh --with-openspec  also install the OpenSpec CLI without asking
#   ./install.sh --no-openspec    never ask about the OpenSpec CLI
#   ./install.sh --with-rtk       also install rtk and run `rtk init -g` without asking
#   ./install.sh --no-rtk         never ask about rtk
#
# Set CLAUDE_SKILLS_DIR to link somewhere other than ~/.claude/skills.
# Existing folders or foreign symlinks with the same name are never touched.
# On Windows, use install.ps1 instead.
# If the openspec CLI (needed by grill-spec) is missing, install asks whether to
# install it with npm; likewise for rtk (token-saving Bash hook), installed with
# its official script. Without a terminal to ask on, both only print a hint.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="$REPO_DIR/skills"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

usage() {
  sed -n '2,21s/^# \{0,1\}//p' "$0"
}

# True if $1 is a symlink this script created, i.e. it points into $SRC_DIR.
is_ours() {
  [[ -L "$1" ]] && [[ "$(readlink "$1")" == "$SRC_DIR/"* ]]
}

link_skill() {
  local name="$1" src="$SRC_DIR/$1" dest="$DEST_DIR/$1"

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "skip    $name: $src/SKILL.md not found"
    return 1
  fi

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
  echo "linked  $name"
}

# Removes symlinks into this repo whose skill folder no longer exists.
prune_stale() {
  local link
  for link in "$DEST_DIR"/*; do
    if is_ours "$link" && [[ ! -e "$link" ]]; then
      rm "$link"
      echo "pruned  $(basename "$link") (skill no longer in repo)"
    fi
  done
}

install() {
  local failed=0 name dir
  mkdir -p "$DEST_DIR"

  if [[ $# -gt 0 ]]; then
    for name in "$@"; do link_skill "$name" || failed=1; done
  else
    for dir in "$SRC_DIR"/*/; do
      [[ -d "$dir" ]] || continue
      name="$(basename "$dir")"
      link_skill "$name" || failed=1
    done
    prune_stale
  fi

  echo
  echo "Skills directory: $DEST_DIR"
  return $failed
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
CLAUDE_SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

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
  [[ -d "$DEST_DIR" ]] || { echo "Nothing to remove: $DEST_DIR does not exist"; return 0; }

  if [[ $# -gt 0 ]]; then
    for name in "$@"; do
      link="$DEST_DIR/$name"
      if is_ours "$link"; then
        rm "$link"; echo "removed $name"; removed=$((removed + 1))
      elif [[ -e "$link" || -L "$link" ]]; then
        echo "WARN    $name: $link was not created by this script; leaving it"
      else
        echo "skip    $name: not installed"
      fi
    done
  else
    for link in "$DEST_DIR"/*; do
      if is_ours "$link"; then
        rm "$link"; echo "removed $(basename "$link")"; removed=$((removed + 1))
      fi
    done
  fi

  echo
  echo "Removed $removed symlink(s) from $DEST_DIR"
}

main() {
  local mode=install openspec=ask rtk=ask
  local -a names=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall) mode=uninstall ;;
      --check)     mode=check ;;
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

  case "$mode" in
    install)
      local failed=0
      install ${names[@]+"${names[@]}"} || failed=1
      install_openspec "$openspec" || failed=1
      install_rtk "$rtk" || failed=1
      return $failed
      ;;
    uninstall) uninstall ${names[@]+"${names[@]}"} ;;
    check)     "$REPO_DIR/scripts/validate.sh" ${names[@]+"${names[@]}"} ;;
  esac
}

main "$@"
