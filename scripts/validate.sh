#!/usr/bin/env bash
# Validates the whole repo:
#   skills/<domain>/<name>/SKILL.md
#     - frontmatter block; `name` matches the folder (lowercase, digits, hyphens, <= 64 chars)
#     - `description` present, <= 1536 chars
#     - optional `targets` ([claude] or [claude, codex]) and `status` (stable|experimental)
#     - names unique across all domains
#     - warning only: codex-targeted skills that use Claude-only constructs
#   agents/<domain>/<name>.md   name matches file, description present, names unique
#   hooks/<domain>/hooks.json   valid JSON with a top-level "hooks" key
#   mcp/<domain>/.mcp.json      valid JSON, no literal tokens (use ${ENV_VAR})
#   .claude-plugin/plugin.json  in sync with the domain folders (scripts/sync-plugin.sh)
#
# Usage: scripts/validate.sh [skill-name ...]   (names limit the skill checks)
# Exits non-zero on any failure. Plain bash + awk + jq; runs on macOS and Linux.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILLS_DIR="$REPO_DIR/skills"

# shellcheck source=scripts/frontmatter.sh
source "$REPO_DIR/scripts/frontmatter.sh"

NAME_RE='^[a-z0-9]+(-[a-z0-9]+)*$'
WARNINGS=0

has_frontmatter() {
  local file="$1" first
  first="$(head -n 1 "$file" | tr -d '\r')"
  [[ "$first" == "---" ]] && [[ "$(awk 'NR > 1 && /^---[[:space:]]*$/ { print "y"; exit }' "$file")" == "y" ]]
}

# Prints the body (everything after the frontmatter) of $1.
body_of() {
  awk 'NR == 1 { next } fm == 0 && /^---[[:space:]]*$/ { fm = 1; next } fm == 1' "$1"
}

# Checks name + description shared by skills and agents. $1 file, $2 label, $3 expected name.
check_name_desc() {
  local file="$1" label="$2" expect="$3" name desc ok=0
  name="$(frontmatter_value "$file" name)"
  desc="$(frontmatter_value "$file" description)"

  if [[ -z "$name" ]]; then
    echo "FAIL $label: frontmatter is missing 'name'"; ok=1
  else
    if [[ "$name" != "$expect" ]]; then
      echo "FAIL $label: name '$name' does not match '$expect'"; ok=1
    fi
    if [[ ! "$name" =~ $NAME_RE ]] || (( ${#name} > 64 )); then
      echo "FAIL $label: name '$name' must be lowercase letters, digits and single hyphens, at most 64 chars"; ok=1
    fi
  fi
  if [[ -z "$desc" ]]; then
    echo "FAIL $label: frontmatter is missing 'description'"; ok=1
  elif (( ${#desc} > 1536 )); then
    echo "FAIL $label: description is ${#desc} chars; Claude Code truncates at 1536"; ok=1
  fi
  return $ok
}

# Warns when a codex-targeted skill uses Claude-only constructs.
portability_lint() {
  local file="$1" label="$2" targets="$3" text hits=""
  [[ "$targets" == *codex* ]] || return 0
  text="$(cat "$file")"
  local pat
  for pat in 'disable-model-invocation' 'argument-hint' '$ARGUMENTS' 'claude -p' 'CLAUDE.md' 'sub-agent' 'subagent' 'Agent tool' 'Task tool'; do
    if grep -qF -- "$pat" <<<"$text"; then hits="$hits '$pat'"; fi
  done
  if [[ -n "$hits" ]]; then
    echo "WARN $label: targets include codex but uses Claude-only constructs:$hits (set targets: [claude]?)"
    WARNINGS=$((WARNINGS + 1))
  fi
}

validate_skill() {
  local dir="$1" domain folder file ok=0 targets status
  folder="$(basename "$dir")"
  domain="$(basename "$(dirname "$dir")")"
  file="$dir/SKILL.md"
  local label="$domain/$folder"

  if [[ ! -f "$file" ]]; then
    echo "FAIL $label: missing SKILL.md"
    return 1
  fi
  if ! has_frontmatter "$file"; then
    echo "FAIL $label: SKILL.md must start with a --- frontmatter block closed by ---"
    return 1
  fi

  check_name_desc "$file" "$label" "$folder" || ok=1

  targets="$(frontmatter_value "$file" targets)"
  if [[ -n "$targets" ]]; then
    case "$(tr -d ' ' <<<"$targets")" in
      "[claude]"|"[claude,codex]") ;;
      *) echo "FAIL $label: targets '$targets' must be [claude] or [claude, codex]"; ok=1 ;;
    esac
  fi
  status="$(frontmatter_value "$file" status)"
  if [[ -n "$status" && "$status" != "stable" && "$status" != "experimental" ]]; then
    echo "FAIL $label: status '$status' must be stable or experimental"; ok=1
  fi

  portability_lint "$file" "$label" "${targets:-[claude, codex]}"

  [[ $ok -eq 0 ]] && echo "ok   $label"
  return $ok
}

validate_agent() {
  local file="$1" base domain ok=0
  base="$(basename "$file" .md)"
  domain="$(basename "$(dirname "$file")")"
  local label="agent $domain/$base"

  if ! has_frontmatter "$file"; then
    echo "FAIL $label: must start with a --- frontmatter block closed by ---"
    return 1
  fi
  check_name_desc "$file" "$label" "$base" || ok=1
  [[ $ok -eq 0 ]] && echo "ok   $label"
  return $ok
}

validate_hooks() {
  local file="$1" label
  label="hooks $(basename "$(dirname "$file")")"
  if ! jq -e 'type == "object" and (.hooks | type == "object")' "$file" >/dev/null 2>&1; then
    echo "FAIL $label: must be valid JSON with a top-level \"hooks\" object"
    return 1
  fi
  echo "ok   $label"
}

validate_mcp() {
  local file="$1" label stripped
  label="mcp $(basename "$(dirname "$file")")"
  if ! jq empty "$file" >/dev/null 2>&1; then
    echo "FAIL $label: not valid JSON"
    return 1
  fi
  # Ignore ${ENV_VAR} references and URLs, then look for token-shaped strings.
  stripped="$(sed -E 's/\$\{[A-Za-z0-9_:-]+\}//g; s#https?://[^"[:space:]]*##g' "$file")"
  if grep -qE 'sk-[A-Za-z0-9]|ghp_|gho_|github_pat_|xox[abprs]-|[A-Za-z0-9+/=_-]{32,}' <<<"$stripped"; then
    echo "FAIL $label: looks like it contains a literal token; reference secrets as \${ENV_VAR}"
    return 1
  fi
  echo "ok   $label"
}

check_plugin_sync() {
  local expected actual
  if ! actual="$(jq -S . "$REPO_DIR/.claude-plugin/plugin.json" 2>/dev/null)"; then
    echo "FAIL plugin.json: not valid JSON"
    return 1
  fi
  expected="$("$REPO_DIR/scripts/sync-plugin.sh" --print | jq -S .)"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL plugin.json: component lists are out of sync with the domain folders; run scripts/sync-plugin.sh"
    return 1
  fi
  echo "ok   plugin.json in sync"
}

# Prints "<name> <path>" lines; used to find duplicates across domains.
report_duplicates() {
  local kind="$1" dups
  dups="$(sort | awk '{ n[$1]++; p[$1] = p[$1] " " $2 } END { for (k in n) if (n[k] > 1) print k ":" p[k] }')"
  if [[ -n "$dups" ]]; then
    while read -r line; do echo "FAIL duplicate $kind name $line"; done <<<"$dups"
    return 1
  fi
}

main() {
  local failed=0 count=0 dir file name
  local -a dirs=()

  if [[ $# -gt 0 ]]; then
    for name in "$@"; do
      dir="$(compgen -G "$SKILLS_DIR/*/$name" | head -n 1 || true)"
      dirs+=("${dir:-$SKILLS_DIR/$name}")
    done
  else
    for dir in "$SKILLS_DIR"/*/*/; do
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

  # Whole-repo checks only when validating everything.
  if [[ $# -eq 0 ]]; then
    local d
    for d in "$SKILLS_DIR"/*/*/; do
      echo "$(basename "$d") ${d#"$REPO_DIR"/}"
    done | report_duplicates skill || failed=$((failed + 1))

    for file in "$REPO_DIR"/agents/*/*.md; do
      [[ -f "$file" ]] || continue
      count=$((count + 1))
      validate_agent "$file" || failed=$((failed + 1))
    done
    for file in "$REPO_DIR"/agents/*/*.md; do
      if [[ -f "$file" ]]; then echo "$(basename "$file" .md) ${file#"$REPO_DIR"/}"; fi
    done | report_duplicates agent || failed=$((failed + 1))

    for file in "$REPO_DIR"/hooks/*/hooks.json; do
      [[ -f "$file" ]] || continue
      count=$((count + 1))
      validate_hooks "$file" || failed=$((failed + 1))
    done
    for file in "$REPO_DIR"/mcp/*/.mcp.json; do
      [[ -f "$file" ]] || continue
      count=$((count + 1))
      validate_mcp "$file" || failed=$((failed + 1))
    done

    count=$((count + 1))
    check_plugin_sync || failed=$((failed + 1))
  fi

  echo
  [[ $WARNINGS -gt 0 ]] && echo "$WARNINGS warning(s)."
  if [[ $failed -gt 0 ]]; then
    echo "$failed of $count check(s) failed validation."
    return 1
  fi
  echo "All $count check(s) valid."
}

main "$@"
