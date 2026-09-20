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

# rune.toolpolicy
require_block 'grep -R TODO .' rune.toolpolicy:grep-use-rg
require_block 'find . -name "*.md"' rune.toolpolicy:find-use-fd
require_allow 'git grep TODO'

# rune.homebrew: a pipe after brew kills its lazy gem install
require_block 'brew info cliproxyapi | head' rune.homebrew:brew-no-pipe
require_block 'brew info x| head' rune.homebrew:brew-no-pipe
require_block 'cd /tmp && brew audit f.rb 2>&1 | head -5' rune.homebrew:brew-no-pipe
require_allow 'brew info cliproxyapi > /tmp/brew.txt 2>&1'
require_allow 'brew info --json=v2 x >| /tmp/brew.json 2>&1'
require_allow 'brew info --json=v2 x > /tmp/brew.json 2>&1; jq ".a | .b" /tmp/brew.json'
require_allow 'brew a && b | c'
require_allow 'brew --version'
require_allow 'brew --prefix cliproxyapi'

# user.aliases: interactive -i aliases need an explicit flag
require_block 'rm /tmp/x' user.aliases:rm-needs-flag
require_block 'mv /tmp/a /tmp/b' user.aliases:mv-needs-flag
require_block 'cd /tmp && rm x' user.aliases:rm-needs-flag
# A flag passes, including after a chain separator and after other options.
require_allow 'rm -f /tmp/x'
require_allow 'cd /tmp && rm -f x'
require_allow 'mv -n /tmp/a /tmp/b'
require_allow 'cp -v -f /tmp/a /tmp/b'

if [ "${failures}" -ne 0 ]; then
    echo "${failures} failure(s)"
    exit 1
fi
echo "dcg packs OK"
