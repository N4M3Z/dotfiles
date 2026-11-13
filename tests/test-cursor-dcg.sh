#!/bin/bash
# The Cursor shell hook must pass a dcg verdict on, and must stop when dcg
# itself fails. Cursor registers the hook with failClosed, so a hook that exits
# non-zero blocks the command. A stub dcg in a temporary home folder stands in
# for the real one: the hook builds its own PATH from $HOME.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
HOOK="${SOURCE_DIR}/dot_cursor/hooks/executable_dcg-pre-shell.sh"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/cursor-dcg.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT
mkdir -p "${WORKDIR}/.local/bin"

failures=0
fail() {
    echo "FAIL $1"
    failures=$((failures + 1))
}

stub() {
    printf '#!/bin/sh\ncat > /dev/null\n%s\n' "$1" > "${WORKDIR}/.local/bin/dcg"
    chmod +x "${WORKDIR}/.local/bin/dcg"
}

run_hook() {
    jq -cn --arg cwd "${WORKDIR}" '{command: "ls", cwd: $cwd}' | HOME="${WORKDIR}" sh "${HOOK}"
}

stub 'exit 0'
if [[ "$(run_hook | jq -r '.permission')" == allow ]]; then
    echo "ok a command that dcg allows is allowed"
else
    fail "a command that dcg allows is not allowed"
fi

stub 'printf "%s\n" "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\",\"ruleId\":\"fixture.rule\"}}"'
if [[ "$(run_hook | jq -r '.permission')" == deny ]]; then
    echo "ok a dcg deny is passed on"
else
    fail "a dcg deny is not passed on"
fi

stub 'exit 3'
if answer=$(run_hook); then
    fail "the hook exits 0 when dcg fails (answer: ${answer})"
elif [[ "${answer}" == *allow* ]]; then
    fail "the hook answers allow when dcg fails"
else
    echo "ok a dcg failure stops the hook"
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-cursor-dcg: ${failures} failure(s)"
    exit 1
fi
echo "test-cursor-dcg: the hook passes verdicts on and fails closed"
