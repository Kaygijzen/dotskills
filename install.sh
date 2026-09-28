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
#
# Set CLAUDE_SKILLS_DIR to link somewhere other than ~/.claude/skills.
# Existing folders or foreign symlinks with the same name are never touched.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="$REPO_DIR/skills"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

usage() {
  sed -n '2,13s/^# \{0,1\}//p' "$0"
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
  local mode=install
  local -a names=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall) mode=uninstall ;;
      --check)     mode=check ;;
      -h|--help)   usage; return 0 ;;
      -*)          echo "Unknown option: $1" >&2; usage >&2; return 2 ;;
      *)           names+=("${1%/}") ;;
    esac
    shift
  done

  case "$mode" in
    install)   install ${names[@]+"${names[@]}"} ;;
    uninstall) uninstall ${names[@]+"${names[@]}"} ;;
    check)     "$REPO_DIR/scripts/validate.sh" ${names[@]+"${names[@]}"} ;;
  esac
}

main "$@"
