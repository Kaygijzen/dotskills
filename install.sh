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
#
# Set CLAUDE_SKILLS_DIR to link somewhere other than ~/.claude/skills.
# Existing folders or foreign symlinks with the same name are never touched.
# If the openspec CLI (needed by grill-spec) is missing, install asks whether to
# install it with npm; without a terminal to ask on, it only prints a hint.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="$REPO_DIR/skills"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

usage() {
  sed -n '2,17s/^# \{0,1\}//p' "$0"
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

# $1 is ask, yes or no.
install_openspec() {
  local choice="$1" reply

  if command -v openspec >/dev/null 2>&1; then
    echo "ok      openspec $(openspec --version 2>/dev/null || echo '(version unknown)')"
    return 0
  fi
  [[ "$choice" == no ]] && return 0

  if [[ "$choice" == ask ]]; then
    if [[ ! -t 0 ]]; then
      echo "note    openspec not found; grill-spec needs it. Rerun with --with-openspec or run: npm install -g $OPENSPEC_PKG"
      return 0
    fi
    read -r -p "OpenSpec CLI not found (grill-spec needs it). Install with npm now? [y/N] " reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || { echo "skip    openspec"; return 0; }
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "WARN    openspec: npm not found; install Node.js, then run: npm install -g $OPENSPEC_PKG"
    return 1
  fi
  if npm install -g "$OPENSPEC_PKG"; then
    echo "installed openspec $(openspec --version 2>/dev/null || true)"
  else
    echo "WARN    openspec: npm install failed (a permissions error usually means npm's global prefix needs sudo or a user-owned prefix)"
    return 1
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
  local mode=install openspec=ask
  local -a names=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall) mode=uninstall ;;
      --check)     mode=check ;;
      --with-openspec) openspec=yes ;;
      --no-openspec)   openspec=no ;;
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
      return $failed
      ;;
    uninstall) uninstall ${names[@]+"${names[@]}"} ;;
    check)     "$REPO_DIR/scripts/validate.sh" ${names[@]+"${names[@]}"} ;;
  esac
}

main "$@"
