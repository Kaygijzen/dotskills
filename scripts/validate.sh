#!/usr/bin/env bash
# Validates every skills/<name>/SKILL.md:
#   - starts with a YAML frontmatter block (--- ... ---)
#   - has a non-empty `name` that matches the folder name
#     (lowercase letters, digits and hyphens, at most 64 characters)
#   - has a non-empty `description` (at most 1536 characters)
#
# Usage: scripts/validate.sh [skill-name ...]
# Exits non-zero if any skill fails. Plain bash + awk; runs on macOS and Linux.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILLS_DIR="$REPO_DIR/skills"

# Prints the value of a top-level frontmatter key. Handles plain, quoted and
# block-scalar (| or >) values; block scalars are joined with spaces.
frontmatter_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit }
    block {
      if ($0 ~ /^[[:space:]]+[^[:space:]]/ || $0 ~ /^[[:space:]]*$/) {
        line = $0; sub(/^[[:space:]]+/, "", line)
        if (line != "") value = value (value == "" ? "" : " ") line
        next
      }
      exit
    }
    $0 ~ "^" key ":" {
      value = $0
      sub("^" key ":[[:space:]]*", "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value ~ /^[|>][-+]?$/) { value = ""; block = 1; next }
      if (value ~ /^".*"$/ || value ~ /^'\''.*'\''$/) value = substr(value, 2, length(value) - 2)
      exit
    }
    END { print value }
  ' "$file"
}

validate_skill() {
  local dir="$1" folder file first name desc ok=0
  folder="$(basename "$dir")"
  file="$dir/SKILL.md"

  if [[ ! -f "$file" ]]; then
    echo "FAIL $folder: missing SKILL.md"
    return 1
  fi

  first="$(head -n 1 "$file" | tr -d '\r')"
  if [[ "$first" != "---" ]] || [[ "$(awk 'NR > 1 && /^---[[:space:]]*$/ { print "y"; exit }' "$file")" != "y" ]]; then
    echo "FAIL $folder: SKILL.md must start with a --- frontmatter block closed by ---"
    return 1
  fi

  name="$(frontmatter_value "$file" name)"
  desc="$(frontmatter_value "$file" description)"

  if [[ -z "$name" ]]; then
    echo "FAIL $folder: frontmatter is missing 'name'"; ok=1
  else
    if [[ "$name" != "$folder" ]]; then
      echo "FAIL $folder: name '$name' does not match folder name '$folder'"; ok=1
    fi
    if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || (( ${#name} > 64 )); then
      echo "FAIL $folder: name '$name' must be lowercase letters, digits and single hyphens, at most 64 chars"; ok=1
    fi
  fi

  if [[ -z "$desc" ]]; then
    echo "FAIL $folder: frontmatter is missing 'description'"; ok=1
  elif (( ${#desc} > 1536 )); then
    echo "FAIL $folder: description is ${#desc} chars; Claude Code truncates at 1536"; ok=1
  fi

  [[ $ok -eq 0 ]] && echo "ok   $folder"
  return $ok
}

main() {
  local failed=0 count=0 dir
  local -a dirs=()

  if [[ $# -gt 0 ]]; then
    for name in "$@"; do dirs+=("$SKILLS_DIR/$name"); done
  else
    for dir in "$SKILLS_DIR"/*/; do
      [[ -d "$dir" ]] && dirs+=("${dir%/}")
    done
  fi

  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "No skills found in $SKILLS_DIR"
    return 1
  fi

  for dir in "${dirs[@]}"; do
    count=$((count + 1))
    if [[ ! -d "$dir" ]]; then
      echo "FAIL $(basename "$dir"): no such skill folder"
      failed=$((failed + 1))
      continue
    fi
    validate_skill "$dir" || failed=$((failed + 1))
  done

  echo
  if [[ $failed -gt 0 ]]; then
    echo "$failed of $count skill(s) failed validation."
    return 1
  fi
  echo "All $count skill(s) valid."
}

main "$@"
