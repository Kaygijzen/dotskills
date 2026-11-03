#!/usr/bin/env bash
# PreToolUse hook: blocks Read/Edit/Write of obvious secret files.
# Reads the hook JSON on stdin. Exit 2 blocks and shows stderr to the model.
# Fails open: without jq, or on unparseable input, the action is allowed.
# Covers only tools that pass a file path; Bash (cat .env), Grep and Glob are not checked.

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  echo "dotskills block-secrets: jq not found, secret-file check skipped" >&2
  exit 0
fi

path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$path" ]] || exit 0

base="${path##*/}"
shopt -s nocasematch  # .ENV and KEY.PEM count too (works in bash 3.2)
case "$base" in
  .env*.example|.env*.sample|.env*.template) exit 0 ;;
  *.pub) exit 0 ;;  # public keys are not secret
  .env|.env.*|*.pem|*.key|*.pfx|*.p12|id_rsa|id_rsa_*|id_ed25519|id_ed25519_*|id_ecdsa|id_ecdsa_*|.npmrc|.netrc|credentials|credentials.json|secrets.json|secrets.yml|secrets.yaml|secrets.toml|secrets.env)
    echo "Blocked: '$base' looks like a secret file (.env*, *.pem, *.key, *.pfx, *.p12, SSH private keys, .npmrc, .netrc, credentials, secrets.{json,yml,yaml,toml,env}). Secrets must not enter the conversation. Ask the user for the specific non-secret values you need, or have them edit the file themselves." >&2
    exit 2
    ;;
esac
exit 0
