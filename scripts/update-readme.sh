#!/usr/bin/env bash
# Rebuilds the generated tables in README.md from frontmatter:
#   skills-table:start/end   skills grouped by domain (incl. invocation: model or user)
#   agents-table:start/end   subagents grouped by domain
# Everything else in the README is left alone.
#
# Usage: scripts/update-readme.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
README="$REPO_DIR/README.md"

# shellcheck source=scripts/frontmatter.sh
source "$REPO_DIR/scripts/frontmatter.sh"

esc() { local s="$1"; echo "${s//|/\\|}"; }

skills_table() {
  local file domain name desc what rest trigger manual targets status invocation
  echo "| Skill | Domain | What it does | Invocation | Trigger | Targets | Status |"
  echo "| --- | --- | --- | --- | --- | --- | --- |"
  for file in "$REPO_DIR"/skills/*/*/SKILL.md; do
    [[ -f "$file" ]] || continue
    domain="$(basename "$(dirname "$(dirname "$file")")")"
    name="$(frontmatter_value "$file" name)"
    desc="$(frontmatter_value "$file" description)"
    manual="$(frontmatter_value "$file" disable-model-invocation)"
    targets="$(frontmatter_value "$file" targets)"
    status="$(frontmatter_value "$file" status)"

    # First sentence is what it does; the rest usually says when to use it.
    what="${desc%%. *}"
    rest=""
    if [[ "$what" != "$desc" ]]; then
      what="$what."
      rest="${desc#*. }"
    fi
    rest="${rest#Use when }"

    invocation="model"
    [[ "$manual" == "true" ]] && invocation="user"

    if [[ "$manual" == "true" ]]; then
      trigger="\`/$name\` only (never auto-invoked)"
    elif [[ -n "$rest" ]]; then
      trigger="\`/$name\`, or automatically when $rest"
    else
      trigger="\`/$name\`, or automatically when relevant"
    fi

    printf '%s\t| `%s` | %s | %s | %s | %s | %s | %s |\n' "$domain" "$name" "$domain" "$(esc "$what")" "$invocation" "$(esc "$trigger")" "${targets:-[claude, codex]}" "${status:-stable}"
  done | LC_ALL=C sort -s -t$'\t' -k1,1 | cut -f2-
}

agents_table() {
  local file domain name desc model
  echo "| Agent | Domain | What it does | Model | Tools |"
  echo "| --- | --- | --- | --- | --- |"
  for file in "$REPO_DIR"/agents/*/*.md; do
    [[ -f "$file" ]] || continue
    domain="$(basename "$(dirname "$file")")"
    name="$(frontmatter_value "$file" name)"
    desc="$(frontmatter_value "$file" description)"
    model="$(frontmatter_value "$file" model)"
    printf '| `%s` | %s | %s | %s | %s |\n' "$name" "$domain" "$(esc "${desc%%. *}")" "${model:-inherit}" "$(esc "$(frontmatter_value "$file" tools)")"
  done
}

# $1 marker name, $2 file holding the new table.
replace_block() {
  local marker="$1" table="$2"
  if ! grep -q "<!-- $marker:start" "$README" || ! grep -q "<!-- $marker:end" "$README"; then
    echo "README.md is missing the $marker:start / $marker:end markers" >&2
    return 1
  fi
  awk -v table="$table" -v m="$marker" '
    index($0, "<!-- " m ":start") { print; while ((getline line < table) > 0) print line; skip = 1; next }
    index($0, "<!-- " m ":end")   { skip = 0 }
    !skip
  ' "$README" > "$README.new"
  cat "$README.new" > "$README"
  rm -f "$README.new"
}

main() {
  t="$(mktemp)"  # global so the EXIT trap can still see it
  trap 'rm -f "$t"' EXIT
  skills_table > "$t"; replace_block skills-table "$t"
  agents_table > "$t"; replace_block agents-table "$t"
  echo "Updated skills and agents tables in README.md"
}

main "$@"
