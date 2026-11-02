#!/usr/bin/env bash
# Tests block-secrets.sh. Usage: hooks/core/scripts/test-block-secrets.sh
set -uo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/block-secrets.sh"
fail=0

# $1 expected exit code, $2 tool, $3 path
check() {
  local want="$1" tool="$2" path="$3" got
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$tool" "$path" | "$HOOK" >/dev/null 2>&1
  got=$?
  if [[ "$got" -ne "$want" ]]; then
    echo "FAIL $tool $path: expected exit $want, got $got"; fail=1
  else
    echo "ok   $tool $path -> $got"
  fi
}

check 2 Read  /p/.env
check 2 Read  /p/.env.local
check 2 Edit  /p/certs/server.pem
check 2 Read  /home/u/.ssh/id_rsa
check 2 Read  /home/u/.ssh/id_rsa_work
check 0 Read  /home/u/.ssh/id_rsa.pub
check 2 Write /p/key.pfx
check 2 Read  /p/secrets.yaml
check 0 Read  /p/.env.example
check 0 Read  /p/README.md
check 0 Edit  /p/src/environment.ts

# No file_path (e.g. a Bash call) is allowed.
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | "$HOOK" >/dev/null 2>&1 || { echo "FAIL no file_path"; fail=1; }
# Garbage input fails open.
echo 'not json' | "$HOOK" >/dev/null 2>&1 || { echo "FAIL garbage input should fail open"; fail=1; }
# Missing jq fails open with a warning.
out="$(echo '{"tool_input":{"file_path":"/p/.env"}}' | PATH=/nonexistent /bin/bash "$HOOK" 2>&1)"; rc=$?
if [[ $rc -ne 0 || "$out" != *"jq not found"* ]]; then echo "FAIL missing jq: rc=$rc out=$out"; fail=1; else echo "ok   missing jq fails open"; fi

[[ $fail -eq 0 ]] && echo "All hook tests passed." || { echo "Hook tests failed."; exit 1; }
