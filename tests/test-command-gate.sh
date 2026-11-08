#!/bin/bash
# harness-command-gate must hold Muse Code to every Bash ask and deny rule of
# Claude Code, and must not stop routine commands.
#
# Each rule in .chezmoidata/harness/claude.json becomes one sample command: a
# "*" becomes "x". A deny sample must be denied. An ask sample must be asked
# or denied, since a deny rule wins over an ask rule. The hand-written cases
# cover the forms a model writes: chains, pipes, rtk, env words, git -C.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/command-gate.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

chezmoi execute-template --source "${SOURCE_DIR}" \
    < "${SOURCE_DIR}/dot_local/bin/executable_harness-command-gate.tmpl" > "${WORKDIR}/gate" || exit 1
render_modify() {
    chezmoi execute-template --source "${SOURCE_DIR}" \
        < "${SOURCE_DIR}/dot_config/muse/modify_settings.json.tmpl" > "${WORKDIR}/modify.sh"
}
render_modify || exit 1
printf '' | bash "${WORKDIR}/modify.sh" > "${WORKDIR}/muse.json" || exit 1

failures=0
fail() {
    echo "FAIL $1"
    failures=$((failures + 1))
}

decide() {
    jq -cn --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "bash", tool_input: {command: $c}}' \
        | bash "${WORKDIR}/gate" \
        | jq -r '.hookSpecificOutput.permissionDecision // empty' 2> /dev/null
}

if jq -e --arg gate "${HOME}/.local/bin/harness-command-gate" '
        any(.hooks.PreToolUse[]; .matcher == "bash" and any(.hooks[]; .command == $gate))
    ' "${WORKDIR}/muse.json" > /dev/null; then
    echo "ok muse runs the command gate before each bash call"
else
    fail "muse settings do not run harness-command-gate before bash calls"
fi

sample() {
    local rule=$1
    [[ "${rule}" == *:\* ]] && rule="${rule%:\*} *"
    printf '%s' "${rule//\*/x}"
}

wrong=()
count=0
while IFS=$'\t' read -r kind rule; do
    count=$((count + 1))
    command_text=$(sample "${rule}")
    result=$(decide "${command_text}")
    case "${kind}:${result}" in
        deny:deny|ask:ask|ask:deny) ;;
        *) wrong+=("${result:-pass} (want ${kind}): ${command_text}   [Bash(${rule})]") ;;
    esac
done < <(jq -r '
    .harness.claude.permissions as $p
    | (($p.deny[] | select(startswith("Bash(") and endswith(")")) | "deny\t" + .[5:-1]),
       ($p.ask[] | select(startswith("Bash(") and endswith(")")) | "ask\t" + .[5:-1]))
' "${SOURCE_DIR}/.chezmoidata/harness/claude.json")
if [[ ${count} -eq 0 ]]; then
    fail "claude.json has no Bash ask or deny rules to check"
elif [[ ${#wrong[@]} -gt 0 ]]; then
    fail "the gate does not hold these Claude rules:"
    printf '    %s\n' "${wrong[@]}"
else
    echo "ok the gate holds every Claude Bash ask and deny rule"
fi

wrong=()
while IFS='|' read -r want command_text; do
    result=$(decide "${command_text}")
    [[ "${result:-pass}" == "${want}" ]] || wrong+=("${result:-pass} (want ${want}): ${command_text}")
done <<'CASES'
ask|git push origin main
ask|cd ~/Developer/x && git push
ask|rtk git push -u origin change/x
ask|rtk proxy git push
ask|GIT_TRACE=1 git push
ask|HOME=/tmp git push
ask|env FOO=/a/b git push
ask|A=1 B=/x gh pr create
ask|GIT_SSH_COMMAND="ssh -i /k/id" git push
ask|/usr/bin/env FOO=/a/b /usr/bin/git push
ask|git -C ~/Developer/x push origin HEAD
ask|git -C "a b" push
ask|git 'push' origin main
ask|"gh" pr create --fill
ask|git --git-dir .git push
ask|git --bare push
ask|git  push
ask|/usr/bin/git push
ask|\git push
ask|timeout 60 git push
ask|timeout -s TERM 60 git push
ask|nice -n 5 git push
ask|stdbuf -oL git push
ask|echo | xargs -n 1 gh pr comment 12 --body ok
ask|bash -c 'git push'
ask|/bin/zsh -fc 'gh pr create'
ask|eval "gh pr create"
ask|env -C /tmp git push
ask|time -o /tmp/time.log git push
ask|echo body | gh pr create --fill
ask|gh pr comment 12 --body ok
deny|gh pr merge 12 --squash
deny|git push --force origin main
deny|true; sudo rm -rf /tmp/x
deny|env sudo rm -rf /tmp/x
deny|HOME=/tmp sudo rm -rf /tmp/x
deny|env FOO=/a/b sudo rm -rf /tmp/x
deny|A=1 B=/x git push --force origin main
deny|timeout 60 git push --force origin main
deny|for b in a; do git push --force origin main; done
deny|if true; then git push --force origin main; fi
deny|{ git push --force origin main; }
deny|! git push --force origin main
deny|env -C /tmp git push --force origin main
deny|sudo -g wheel rm -rf /tmp/x
pass|git status
pass|HOME=/tmp git status
pass|env FOO=/a/b git status
pass|gh pr view 12
pass|jj log -r @
pass|cargo test
pass|rg -n push src
pass|nice git status
pass|bash tests/test-command-gate.sh
pass|bash deploy.sh -config x
pass|sh build.sh --clean
ask|bash -l -c 'git push'
ask|bash -o pipefail -c 'git push'
ask|bash --norc -c 'gh pr create'
ask|sh -ec 'gh pr create'
CASES
for command_text in $'git push \\\n  --force origin main' $'git p\\\nush --force origin main'; do
    result=$(decide "${command_text}")
    [[ "${result}" == deny ]] || wrong+=("${result:-pass} (want deny): continued force push")
done
if [[ ${#wrong[@]} -gt 0 ]]; then
    fail "the gate decides these commands wrong:"
    printf '    %s\n' "${wrong[@]}"
else
    echo "ok the gate asks for remote writes in chains and passes routine work"
fi

for payload in '' $' \t\n' 'not json'; do
    broken=$(printf '%s' "${payload}" | bash "${WORKDIR}/gate" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2> /dev/null)
    if [[ "${broken}" != deny ]]; then
        fail "the gate does not deny an empty, blank, or malformed payload"
    fi
done
other=$(jq -cn '{tool_name: "read_file", tool_input: {path: "/tmp/x"}}' | bash "${WORKDIR}/gate")
if [[ -z "${other}" ]]; then
    echo "ok the gate denies a payload it cannot read and ignores other tools"
else
    fail "the gate does not fail closed on a bad payload, or it answers for other tools"
fi

# Muse runs the hook with the script's own interpreter, /bin/bash, which is 3.2
# on macOS. A heredoc or inline JSON makes a long command, and the gate must
# still answer quickly. A slow answer may let Muse run the call ungated.
if command -v timeout > /dev/null 2>&1; then
    long=$(printf 'a%.0s' $(seq 1 20000))
    started=${SECONDS}
    result=$(jq -cn --arg c "echo ${long}; git push" \
            '{hook_event_name: "PreToolUse", tool_name: "bash", tool_input: {command: $c}}' \
        | timeout 20 /bin/bash "${WORKDIR}/gate" \
        | jq -r '.hookSpecificOutput.permissionDecision // empty' 2> /dev/null)
    if [[ "${result}" == ask ]]; then
        echo "ok the gate answers a 20 KB command in $((SECONDS - started)) s with /bin/bash"
    else
        fail "the gate does not answer a 20 KB command within 20 s with /bin/bash (got '${result}')"
    fi
else
    echo "skip timeout is not installed, so the long-command check does not run"
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-command-gate: ${failures} failure(s)"
    exit 1
fi
echo "test-command-gate: the gate holds muse to Claude's Bash rules"
