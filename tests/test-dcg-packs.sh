#!/usr/bin/env bash
# Validates every user-level dcg pack in dot_config/dcg/packs and checks the
# deny and allow cases each pack promises. dcg loads the deployed copies from
# ~/.config/dcg/packs, so run `chezmoi apply` before this when a pack changed.
# Source: https://github.com/N4M3Z/dotfiles
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
failures=0

command -v dcg >/dev/null 2>&1 || { echo "dcg not installed" >&2; exit 1; }

for pack in "${ROOT}"/dot_config/dcg/packs/*.yaml; do
    if dcg pack validate "${pack}" >/dev/null 2>&1; then
        echo "PASS: validate $(basename "${pack}")"
    else
        echo "FAIL: validate $(basename "${pack}")"
        failures=$((failures + 1))
    fi
done

require_block() {
    local command_text=$1
    local rule_id=$2
    local output
    set +e
    output=$(dcg --robot test "${command_text}" 2>&1)
    set -e
    if printf '%s\n' "${output}" | rg -Fq "\"rule_id\": \"${rule_id}\""; then
        echo "PASS: deny ${rule_id}: ${command_text}"
    else
        echo "FAIL: expected ${rule_id} for: ${command_text}"
        failures=$((failures + 1))
    fi
}

require_allow() {
    local command_text=$1
    local output
    set +e
    output=$(dcg --robot test "${command_text}" 2>&1)
    set -e
    if printf '%s\n' "${output}" | rg -Fq '"decision": "allow"'; then
        echo "PASS: allow: ${command_text}"
    else
        echo "FAIL: expected allow for: ${command_text}"
        failures=$((failures + 1))
    fi
}

# The rune.* packs (search, parsers, secrets, push, provenance, rtk, homebrew)
# live in every runedeck repository under .dcg/packs/ and are replayed by
# that repository's scripts/test-dcg-packs. Only the host packs stay here.

# user.secrets: a casual secret read is denied from any directory
require_block 'cat ~/.env' user.secrets:casual-secret-read
require_block 'head ~/.ssh/id_rsa' user.secrets:casual-secret-read
require_block 'cat .env.example .env' user.secrets:casual-secret-read
require_allow 'cat .env.example'

# user.aliases: interactive -i aliases need an explicit flag
require_block 'rm /tmp/x' user.aliases:rm-needs-flag
require_block 'mv /tmp/a /tmp/b' user.aliases:mv-needs-flag
require_block 'cd /tmp && rm x' user.aliases:rm-needs-flag
# A flag passes, including after a chain separator and after other options.
require_allow 'rm -f /tmp/x'
require_allow 'cd /tmp && rm -f x'
require_allow 'mv -n /tmp/a /tmp/b'
require_allow 'cp -v -f /tmp/a /tmp/b'
# Extra whitespace must not defeat the flag check (the lookahead consumes it).
require_allow 'cp  -f /tmp/a /tmp/b'
require_allow 'cd /tmp &&  rm  -f x'
require_block 'cp  /tmp/a /tmp/b' user.aliases:cp-needs-flag

if [ "${failures}" -ne 0 ]; then
    echo "${failures} failure(s)"
    exit 1
fi
echo "dcg packs OK"
