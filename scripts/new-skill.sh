#!/usr/bin/env bash
# Scaffolds skills/<domain>/<name>/SKILL.md from templates/SKILL.md.
# Fails if the domain folder doesn't exist or the name is already used.
#
# Usage: scripts/new-skill.sh <domain> <name>

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

main() {
  if [[ $# -ne 2 ]]; then
    echo "Usage: scripts/new-skill.sh <domain> <name>" >&2
    return 2
  fi
  local domain="$1" name="$2" existing
  if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || (( ${#name} > 64 )); then
    echo "Invalid name '$name': use lowercase letters, digits and single hyphens, at most 64 chars" >&2
    return 1
  fi
  if [[ ! -d "$REPO_DIR/skills/$domain" ]]; then
    echo "Domain '$domain' does not exist. Existing domains:" >&2
    ls "$REPO_DIR/skills" >&2
    echo "Create a new domain with: mkdir skills/$domain (see README: Adding a domain)" >&2
    return 1
  fi
  existing="$(compgen -G "$REPO_DIR/skills/*/$name" || true)"
  if [[ -n "$existing" ]]; then
    echo "Skill name '$name' is already taken: $existing" >&2
    return 1
  fi
  mkdir -p "$REPO_DIR/skills/$domain/$name"
  sed "s/__NAME__/$name/g" "$REPO_DIR/templates/SKILL.md" > "$REPO_DIR/skills/$domain/$name/SKILL.md"
  echo "Created skills/$domain/$name/SKILL.md"
  echo "Next: edit it, run scripts/sync-plugin.sh and scripts/update-readme.sh, then scripts/validate.sh"
}

main "$@"
