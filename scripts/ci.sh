#!/usr/bin/env bash
# Runs every check. Used locally and by .github/workflows/validate.yml.
# Usage: scripts/ci.sh

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_DIR" || exit
failed=0

step() { echo; echo "== $1"; }
fail() { echo "FAILED: $1"; failed=1; }

step "validate.sh"
./scripts/validate.sh || fail validate

step "generated files are up to date"
cp README.md /tmp/README.ci.$$ && cp .claude-plugin/plugin.json /tmp/plugin.ci.$$
./scripts/update-readme.sh >/dev/null && ./scripts/sync-plugin.sh >/dev/null
if ! cmp -s README.md /tmp/README.ci.$$ || ! cmp -s .claude-plugin/plugin.json /tmp/plugin.ci.$$; then
  cat /tmp/README.ci.$$ > README.md; cat /tmp/plugin.ci.$$ > .claude-plugin/plugin.json
  fail "README tables or plugin.json are stale; run scripts/update-readme.sh and scripts/sync-plugin.sh"
fi
rm -f /tmp/README.ci.$$ /tmp/plugin.ci.$$

step "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  sc=(shellcheck)
elif command -v uvx >/dev/null 2>&1; then
  sc=(uvx --from shellcheck-py shellcheck)
else
  sc=()
fi
if (( ${#sc[@]} )); then
  sh_files=()
  while IFS= read -r f; do sh_files+=("$f"); done < <(git ls-files '*.sh'; git ls-files --others --exclude-standard '*.sh')
  "${sc[@]}" -S warning -x "${sh_files[@]}" || fail shellcheck
else
  fail "shellcheck not found; install it (apt install shellcheck) or uv (uvx runs it)"
fi

step "JSON files parse"
while IFS= read -r f; do
  jq empty "$f" || fail "invalid JSON: $f"
done < <({ git ls-files '*.json' '*.mcp.json'; git ls-files --others --exclude-standard '*.json'; } | sort -u)

step "hook tests"
./hooks/core/scripts/test-block-secrets.sh || fail "hook tests"
./hooks/core/scripts/test-load-conventions.sh || fail "load-conventions tests"
./skills/core/setup-dotskills/scripts/test-setup.sh || fail "setup tests"
./statusline/test-statusline.sh || fail "statusline tests"
./skills/engineering/ralph-apply/scripts/test-ralph.sh || fail "ralph tests"

step "claude plugin validate"
if command -v claude >/dev/null 2>&1; then
  claude plugin validate . || fail "claude plugin validate"
else
  echo "claude CLI not installed; skipping"
fi

step "secret scan"
# Token-shaped strings in tracked files (this script and the validator hold the patterns).
pattern='(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[abprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AIza[0-9A-Za-z_-]{35})'
hits="$({ git ls-files; git ls-files --others --exclude-standard; } | sort -u | grep -vE '^(scripts/ci\.sh|scripts/validate\.sh|prompt\.md)$' | xargs grep -InE "$pattern" 2>/dev/null || true)"
if [[ -n "$hits" ]]; then
  echo "$hits"
  fail "possible secret found"
else
  echo "no secrets found"
fi

echo
if [[ $failed -ne 0 ]]; then echo "CI FAILED"; exit 1; fi
echo "CI passed"
