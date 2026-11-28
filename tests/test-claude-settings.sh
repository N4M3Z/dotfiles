#!/bin/bash
# The rendered Claude Code settings keep the claude.ai plugin sync off.
#
# Claude Code loads the plugins enabled on the claude.ai account in every
# session, and their MCP servers ask for a sign-in at every start. The modify
# script rebuilds settings.json from the template at each apply, so the
# template must hold syncClaudeAiPlugins false, even when the live file says
# otherwise.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/claude-settings.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

chezmoi execute-template --source "${SOURCE_DIR}" \
    < "${SOURCE_DIR}/dot_claude/modify_private_settings.json.tmpl" \
    > "${WORKDIR}/modify.sh" || exit 1

failures=0

# Empty stdin is a machine without settings.json. The second live file is one
# where the sync was turned back on by hand.
for live in '' '{"syncClaudeAiPlugins": true}'; do
    if printf '%s' "${live}" | bash "${WORKDIR}/modify.sh" \
        | jq -e '.syncClaudeAiPlugins == false' >/dev/null; then
        echo "PASS: the settings turn the claude.ai plugin sync off (live: ${live:-none})"
    else
        echo "FAIL: the settings leave the claude.ai plugin sync on (live: ${live:-none})"
        failures=$((failures + 1))
    fi
done

exit $(( failures > 0 ))
