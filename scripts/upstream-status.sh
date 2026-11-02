#!/usr/bin/env bash
# Reports how imported skills (upstream.json) differ from upstream. Report-only:
# it never merges or edits anything in this repo. Needs network access, so CI
# does not run it.
#
# For each entry:
#   upstream changed  files under source_path differ between the recorded commit and upstream main
#   locally changed   our copy differs from upstream at the recorded commit
# Entries that are both need a manual merge.
#
# Usage: scripts/upstream-status.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MANIFEST="$REPO_DIR/upstream.json"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 0; }
command -v git >/dev/null || { echo "git is required" >&2; exit 0; }
[[ -f "$MANIFEST" ]] || { echo "No upstream.json, nothing to check."; exit 0; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# One clone per distinct source_repo. Sets CLONE_DIR; runs in the parent shell
# (not a subshell) so the cache survives between calls.
declare -A clones=()
CLONE_DIR=""
clone_for() {
  local repo="$1" dir
  if [[ -z "${clones[$repo]:-}" ]]; then
    dir="$tmp/clone-${#clones[@]}"
    if ! git clone -q "$repo" "$dir" 2>/dev/null; then
      echo "Could not clone $repo (offline?)" >&2
      return 1
    fi
    clones[$repo]="$dir"
  fi
  CLONE_DIR="${clones[$repo]}"
}

both=() upstream_only=() local_only=() clean=() unknown=()

while IFS=$'\t' read -r skill domain repo path commit renamed; do
  clone_for "$repo" || { unknown+=("$skill"); continue; }
  dir="$CLONE_DIR"
  mine="$REPO_DIR/skills/$domain/$skill"

  up_changed=no
  if ! git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null; then
    unknown+=("$skill"); continue
  fi
  if [[ -n "$(git -C "$dir" diff --stat "$commit..origin/HEAD" -- "$path")" ]]; then up_changed=yes; fi

  # Compare our copy with upstream's files at the recorded commit.
  base="$tmp/base-$skill"
  mkdir -p "$base"
  git -C "$dir" archive "$commit" "$path" | tar -x -C "$base"
  local_changed=no
  if ! diff -r "$base/$path" "$mine" >/dev/null 2>&1; then local_changed=yes; fi

  if [[ "$up_changed" == yes && "$local_changed" == yes ]]; then both+=("$skill")
  elif [[ "$up_changed" == yes ]]; then upstream_only+=("$skill")
  elif [[ "$local_changed" == yes ]]; then local_only+=("$skill")
  else clean+=("$skill"); fi
done < <(jq -r '.[] | [.skill, .domain, .source_repo, .source_path, .commit, (.renamed_from // "")] | @tsv' "$MANIFEST")

show() { local title="$1"; shift; if [[ $# -gt 0 ]]; then echo "$title"; printf '  %s\n' "$@"; echo; fi; }

echo "Upstream status (report only)"
echo
show "!! UPSTREAM CHANGED AND LOCALLY CHANGED (merge by hand):" "${both[@]}"
show "Upstream changed, no local changes (re-copy and bump commit):" "${upstream_only[@]}"
show "Locally changed only (see local_changes in upstream.json):" "${local_only[@]}"
show "Identical to upstream at the recorded commit:" "${clean[@]}"
show "Could not check (offline, or commit not found):" "${unknown[@]}"
exit 0
