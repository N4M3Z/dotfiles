#!/bin/bash
# dcg must run before every Muse bash call, and Muse must get an answer it
# obeys.
#
# Muse sends Claude Code's PreToolUse payload with tool_name "bash" and obeys
# Claude's hookSpecificOutput.permissionDecision. tests/fixtures holds one such
# payload, recorded from Muse 1.4.14 with the paths and ids made synthetic.
#
# dcg has no Muse profile because it cannot tell Muse apart: the turn_id field
# makes it read a Muse event as a Codex event, and its hook mode takes no agent
# override. The last check fails when that changes, so a Muse profile can be
# added then. A host without dcg, such as the CI runner, checks only the hook
# entry.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/muse-dcg.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT
FIXTURE="${SOURCE_DIR}/tests/fixtures/muse-pretooluse.json"

render() {
    chezmoi execute-template --source "${SOURCE_DIR}" < "${SOURCE_DIR}/$1"
}

render dot_config/muse/modify_settings.json.tmpl > "${WORKDIR}/modify.sh" || exit 1
printf '' | bash "${WORKDIR}/modify.sh" > "${WORKDIR}/muse.json" || exit 1
render dot_config/dcg/config.toml.tmpl > "${WORKDIR}/config.toml" || exit 1

failures=0
fail() {
    echo "FAIL $1"
    failures=$((failures + 1))
}

if jq -e --arg dcg "${HOME}/.local/bin/dcg" '
        any(.hooks.PreToolUse[]; .matcher == "bash" and any(.hooks[]; .type == "command" and .command == $dcg))
    ' "${WORKDIR}/muse.json" > /dev/null; then
    echo "ok muse runs dcg by its absolute path before each bash call"
else
    fail "muse settings do not run dcg before bash calls"
fi

DCG=$(command -v dcg)
if [[ -z "${DCG}" ]]; then
    echo "skip dcg is not installed, so the muse payload is not run"
else
    # The live hook entry calls dcg with no subcommand. DCG_CONFIG points it at
    # the rendered config. `dcg hook` ignores DCG_CONFIG, so it is not used.
    decide() {
        jq -c --arg c "$1" '.tool_input.command = $c' "${FIXTURE}" \
            | DCG_CONFIG="$2" "${DCG}" 2> /dev/null \
            | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2> /dev/null
    }

    wrong=()
    for command_text in "git reset --hard" "git push --force origin main" "git clean -fdx"; do
        result=$(decide "${command_text}" "${WORKDIR}/config.toml")
        [[ "${result}" == deny ]] || wrong+=("${result:-none} (want deny): ${command_text}")
    done
    for command_text in "git status" "jj log -r @" "cargo test"; do
        result=$(decide "${command_text}" "${WORKDIR}/config.toml")
        [[ "${result:-allow}" == allow ]] || wrong+=("${result} (want allow): ${command_text}")
    done
    if [[ ${#wrong[@]} -gt 0 ]]; then
        fail "dcg decides the muse payload wrong:"
        printf '    %s\n' "${wrong[@]}"
    else
        echo "ok dcg reads the muse payload and answers in the form muse obeys"
    fi

    # strict_git denies `git add -A`, which dcg allows by default. A config that
    # adds it only for codex shows which profile a Muse event gets.
    printf '[agents.codex]\nextra_packs = ["strict_git"]\n' > "${WORKDIR}/codex.toml"
    printf '[agents.muse]\nextra_packs = ["strict_git"]\n' > "${WORKDIR}/muse.toml"
    as_codex=$(decide "git add -A" "${WORKDIR}/codex.toml")
    as_muse=$(decide "git add -A" "${WORKDIR}/muse.toml")
    if [[ "${as_codex}" == deny && "${as_muse}" != deny ]]; then
        echo "ok known gap: dcg reads a muse event as codex, so muse has no dcg profile of its own"
    else
        fail "dcg no longer reads a muse event as codex (codex: ${as_codex}, muse: ${as_muse}); give muse its own [agents] profile"
    fi
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-muse-dcg: ${failures} failure(s)"
    exit 1
fi
echo "test-muse-dcg: dcg guards every muse bash call"
