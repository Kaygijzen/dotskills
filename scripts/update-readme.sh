#!/usr/bin/env bash
# Rebuilds the skills table in README.md from each skills/<name>/SKILL.md
# frontmatter. The table sits between the skills-table:start and
# skills-table:end HTML comments; everything else in the README is left alone.
#
# Usage: scripts/update-readme.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
README="$REPO_DIR/README.md"

# shellcheck source=scripts/frontmatter.sh
source "$REPO_DIR/scripts/frontmatter.sh"

build_table() {
  local file name desc what rest trigger manual
  echo "| Skill | What it does | Trigger |"
  echo "| --- | --- | --- |"
  for file in "$REPO_DIR"/skills/*/SKILL.md; do
    [[ -f "$file" ]] || continue
    name="$(frontmatter_value "$file" name)"
    desc="$(frontmatter_value "$file" description)"
    manual="$(frontmatter_value "$file" disable-model-invocation)"

    # First sentence is what it does; the rest usually says when to use it.
    what="${desc%%. *}"
    rest=""
    if [[ "$what" != "$desc" ]]; then
      what="$what."
      rest="${desc#*. }"
    fi
    rest="${rest#Use when }"

    if [[ "$manual" == "true" ]]; then
      trigger="\`/$name\` only (never auto-invoked)"
    elif [[ -n "$rest" ]]; then
      trigger="\`/$name\`, or automatically when $rest"
    else
      trigger="\`/$name\`, or automatically when relevant"
    fi

    printf '| `%s` | %s | %s |\n' "$name" "${what//|/\\|}" "${trigger//|/\\|}"
  done
}

main() {
  if ! grep -q '<!-- skills-table:start' "$README" || ! grep -q '<!-- skills-table:end' "$README"; then
    echo "README.md is missing the skills-table:start / skills-table:end markers" >&2
    return 1
  fi

  table="$(mktemp)"  # global so the EXIT trap can still see it
  trap 'rm -f "$table" "$table.readme"' EXIT
  build_table > "$table"

  awk -v table="$table" '
    /<!-- skills-table:start/ { print; while ((getline line < table) > 0) print line; skip = 1; next }
    /<!-- skills-table:end/   { skip = 0 }
    !skip
  ' "$README" > "$table.readme"
  cat "$table.readme" > "$README"
  echo "Updated skills table in README.md"
}

main "$@"
