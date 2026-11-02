#!/usr/bin/env bash
# PreToolUse hook: blocks Read/Edit/Write of obvious secret files.
# Reads the hook JSON on stdin. Exit 2 blocks and shows stderr to the model.
# Fails open: without jq, or on unparseable input, the action is allowed.

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  echo "dotskills block-secrets: jq not found, secret-file check skipped" >&2
  exit 0
fi

path="$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$path" ]] || exit 0

base="${path##*/}"
case "$base" in
  .env.example|.env.sample|.env.template) exit 0 ;;
  id_rsa*.pub) exit 0 ;;  # public keys are not secret
  .env|.env.*|*.pem|id_rsa*|*.pfx|secrets.*)
    echo "Blocked: '$base' looks like a secret file (.env*, *.pem, id_rsa*, *.pfx, secrets.*). Secrets must not enter the conversation. Ask the user for the specific non-secret values you need, or have them edit the file themselves." >&2
    exit 2
    ;;
esac
exit 0
