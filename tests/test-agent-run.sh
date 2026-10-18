#!/bin/bash
# Regression tests for the fallback launcher `just -g agent run`.
# Source: https://github.com/N4M3Z/dotfiles

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
RUNNER="${ROOT}/dot_config/just/agent/executable_run"
failures=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

assert_log_contains() {
    local pattern="$1"
    local label="$2"

    if grep -Fq -- "$pattern" "$HARNESS_TEST_LOG"; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_log_excludes() {
    local pattern="$1"
    local label="$2"

    if grep -Fq -- "$pattern" "$HARNESS_TEST_LOG"; then
        fail "$label"
    else
        pass "$label"
    fi
}

# The detached capture lands after the launcher exits; give it a moment.
wait_for_log() {
    local pattern="$1"
    local tries=0

    until grep -Fq -- "$pattern" "$HARNESS_TEST_LOG" || (( tries >= 50 )); do
        sleep 0.1
        tries=$((tries + 1))
    done
}

make_fake_harnesses() {
    local bin="$1"
    local name

    mkdir -p "$bin"
    for name in claude codex agy grok opencode; do
        # shellcheck disable=SC2016 # These lines are the generated fake script.
        printf '%s\n' \
            '#!/bin/bash' \
            'printf "command=%s args=" "${0##*/}" >> "$HARNESS_TEST_LOG"' \
            'printf "%q " "$@" >> "$HARNESS_TEST_LOG"' \
            'printf "opencode_permission=%s\n" "${OPENCODE_PERMISSION:-}" >> "$HARNESS_TEST_LOG"' \
            'if [[ -n "${HARNESS_TEST_JJ_REPO:-}" ]]; then' \
            '    cd "$HARNESS_TEST_JJ_REPO" || exit 1' \
            '    printf "%s\n" "material from ${0##*/} $$" > material.txt' \
            '    jj status >/dev/null' \
            'fi' \
            'exit "${HARNESS_FAKE_STATUS:-0}"' \
            > "${bin}/${name}"
        chmod +x "${bin}/${name}"
    done
}

# Every run waits for its own capture line, so a detached capture from one
# test never lands in the next test's log.
run_harness() {
    : > "$HARNESS_TEST_LOG"
    if [[ "${HARNESS_TEST_DEBUG:-0}" == '1' ]]; then
        HARNESS_REAL_BIN_DIR="$fake_bin" SESSION_SYNC="$session_sync" "$RUNNER" "$@"
    else
        HARNESS_REAL_BIN_DIR="$fake_bin" SESSION_SYNC="$session_sync" \
            "$RUNNER" "$@" >/dev/null 2>&1
    fi
    run_status=$?
    wait_for_log 'capture args='
    return "$run_status"
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/agent-run-tests.XXXXXX")"
trap 'command rm -rf "$tmp"' EXIT
fake_bin="${tmp}/bin"
session_sync="${tmp}/session-sync"
export HARNESS_TEST_LOG="${tmp}/harness.log"
# The tests never reach a proxy: grok's route injection is bypassed.
export CLIPROXY_BYPASS=1
make_fake_harnesses "$fake_bin"
cd "$tmp" || exit 1

# The fake capture records what it was handed.
# shellcheck disable=SC2016 # Expands when the fake runs.
printf '%s\n' '#!/bin/bash' \
    'printf "capture args=%s\n" "$*" >> "$HARNESS_TEST_LOG"' \
    'exit 0' > "$session_sync"
chmod +x "$session_sync"
# A capture that blocks for longer than any test may wait.
printf '%s\n' '#!/bin/bash' \
    'printf "slow capture started\n" >> "$HARNESS_TEST_LOG"' \
    'sleep 30' > "${tmp}/slow-sync"
chmod +x "${tmp}/slow-sync"

run_harness claude --help
assert_log_contains 'command=claude args=--help' 'Claude launcher reaches the real binary'
assert_log_excludes '--model' 'interactive Claude leaves the model default untouched'

run_harness codex review
assert_log_contains 'command=codex args=review' 'interactive Codex preserves arguments'
assert_log_excludes '--model' 'interactive Codex leaves the model default untouched'

run_harness antigravity --help
assert_log_contains 'command=agy args=--sandbox --help' 'Antigravity always enables its native sandbox'

run_harness grok --help
assert_log_contains '--sandbox workspace-local' 'interactive Grok uses the workspace sandbox profile'

HARNESS_AUTOMATED=1 run_harness claude -p scan
assert_log_contains '--model claude-fable-5' 'automated Claude pins Fable'
assert_log_contains '--permission-mode plan' 'automated Claude is read-only'

HARNESS_AUTOMATED=1 run_harness codex review
assert_log_contains '--sandbox read-only' 'automated Codex is read-only'
assert_log_contains '--ask-for-approval never' 'automated Codex cannot stall on approval'

HARNESS_AUTOMATED=1 run_harness codex -- --sandbox
assert_log_contains 'args=--ask-for-approval never --sandbox read-only --model gpt-5.5 -- --sandbox' \
    'an option after -- does not count as given'

HARNESS_AUTOMATED=1 run_harness antigravity --help
assert_log_contains 'Gemini\ 3.5\ Flash\ \(High\)' 'automated Antigravity pins Gemini 3.5 Flash High'

HARNESS_AUTOMATED=1 run_harness grok --help
assert_log_contains '--sandbox review-local' 'automated Grok is read-only'
assert_log_contains '--permission-mode dontAsk' 'automated Grok denies unapproved tools instead of prompting'

OPENCODE_PERMISSION='{"*":"deny"}' HARNESS_AUTOMATED=1 run_harness opencode --help
assert_log_contains 'opencode_permission={"*":"deny"}' 'an existing OpenCode permission passes through unchanged'
if grep -Fq 'opencode_permission={"*":"deny"}}' "$HARNESS_TEST_LOG"; then
    fail 'an existing OpenCode permission gains no stray brace'
else
    pass 'an existing OpenCode permission gains no stray brace'
fi

if HARNESS_FAKE_STATUS=7 run_harness claude -p scan; then
    fail 'harness failure status is preserved'
elif [[ "$?" -eq 7 ]]; then
    pass 'harness failure status is preserved'
else
    fail 'harness failure status is preserved'
fi
assert_log_contains 'capture args=--provider claude --source wrapper --status 7' \
    'capture is handed the provider and the exit status'

: > "$HARNESS_TEST_LOG"
started=$(date +%s)
HARNESS_REAL_BIN_DIR="$fake_bin" SESSION_SYNC="${tmp}/slow-sync" "$RUNNER" claude -p scan >/dev/null 2>&1
elapsed=$(( $(date +%s) - started ))
wait_for_log 'slow capture started'
if (( elapsed < 3 )) && grep -Fq 'slow capture started' "$HARNESS_TEST_LOG"; then
    pass 'a blocking capture script never delays the exit'
else
    fail 'a blocking capture script never delays the exit'
fi

if HARNESS_REAL_BIN_DIR="$fake_bin" SESSION_SYNC="${tmp}/absent-sync" HARNESS_FAKE_STATUS=7 \
    "$RUNNER" claude -p scan >/dev/null 2>"${tmp}/absent.err"; then
    fail 'a missing capture script keeps the harness status'
elif [[ "$?" -eq 7 ]] && grep -q 'session-sync not found' "${tmp}/absent.err"; then
    pass 'a missing capture script keeps the harness status and is reported once'
else
    fail 'a missing capture script keeps the harness status and is reported once'
fi

jj_repo="${tmp}/jj-repo"
mkdir -p "$jj_repo"
git -C "$jj_repo" init -q -b main
(cd "$jj_repo" && JJ_CONFIG='' jj git init --colocate >/dev/null)
(cd "$jj_repo" && JJ_USER='Tester' JJ_EMAIL='tester@example.com' HARNESS_AUTOMATED=1 \
    HARNESS_TEST_JJ_REPO="$jj_repo" run_harness codex review)
if git -C "$jj_repo" log -1 --format='%an <%ae>' \
    | grep -Fxq 'Codex (gpt-5.5) <gpt-5.5@codex.noreply.nexus.local>'; then
    pass 'automated run authors its change as the model identity'
else
    fail 'automated run authors its change as the model identity'
fi
if git -C "$jj_repo" log -1 --format=%B | grep -Fq 'Co-authored-by:'; then
    fail 'automated run writes no co-author trailer'
else
    pass 'automated run writes no co-author trailer'
fi
if git -C "$jj_repo" log -1 --format=%s | grep -Fq 'chore: Codex automated session'; then
    pass 'automated run closes its change with a final description'
else
    fail 'automated run closes its change with a final description'
fi
if (cd "$jj_repo" && JJ_CONFIG='' jj log -r @ --no-graph -T 'author.name()' | grep -Fxq 'Tester'); then
    pass 'the working-copy change left behind carries the caller identity'
else
    fail 'the working-copy change left behind carries the caller identity'
fi

(cd "$jj_repo" && HARNESS_AUTOMATED=1 HARNESS_TEST_JJ_REPO="$jj_repo" \
    run_harness codex --model gpt-6-astra review)
if git -C "$jj_repo" log -1 --format='%an <%ae>' \
    | grep -Fxq 'Codex (gpt-6-astra) <gpt-6-astra@codex.noreply.nexus.local>'; then
    pass 'an explicit model names the author'
else
    fail 'an explicit model names the author'
fi

(cd "$jj_repo" && HARNESS_AUTOMATED=1 HARNESS_MODEL='Gemini 3.5 Flash (High)' HARNESS_TEST_JJ_REPO="$jj_repo" \
    run_harness antigravity --help)
if git -C "$jj_repo" log -1 --format='%an <%ae>' \
    | grep -Fxq 'Antigravity (gemini-3.5-flash-high) <gemini-3.5-flash-high@antigravity.noreply.nexus.local>'; then
    pass 'a model name with spaces and parentheses becomes a plain identity'
else
    fail 'a model name with spaces and parentheses becomes a plain identity'
fi

if HARNESS_AUTOMATED=1 HARNESS_MODEL='..' run_harness codex review; then
    fail 'a model that yields no mail address is refused'
else
    pass 'a model that yields no mail address is refused'
fi

empty_repo="${tmp}/empty-jj-repo"
mkdir -p "$empty_repo"
git -C "$empty_repo" init -q -b main
(cd "$empty_repo" && JJ_CONFIG='' jj git init --colocate >/dev/null)
before_empty=$(cd "$empty_repo" && JJ_CONFIG='' jj log -r 'all()' --no-graph -T 'change_id ++ "\n"' | wc -l | tr -d ' ')
(cd "$empty_repo" && JJ_USER='Tester' JJ_EMAIL='tester@example.com' HARNESS_AUTOMATED=1 \
    HARNESS_TEST_JJ_REPO='' run_harness codex review)
after_empty=$(cd "$empty_repo" && JJ_CONFIG='' jj log -r 'all()' --no-graph -T 'change_id ++ "\n"' | wc -l | tr -d ' ')
if [[ "$before_empty" == "$after_empty" ]] \
    && (cd "$empty_repo" && JJ_CONFIG='' jj log -r @ --no-graph -T 'if(description == "", "clear", "kept")' | grep -Fxq clear) \
    && (cd "$empty_repo" && JJ_CONFIG='' jj log -r @ --no-graph -T 'author.name()' | grep -Fxq 'Tester'); then
    pass 'review-only automated run clears its claim without abandoning the working copy'
else
    fail 'review-only automated run clears its claim without abandoning the working copy'
fi

occupied_repo="${tmp}/occupied-jj-repo"
mkdir -p "$occupied_repo"
git -C "$occupied_repo" init -q -b main
(cd "$occupied_repo" && JJ_CONFIG='' jj git init --colocate >/dev/null)
printf '%s\n' prior > "${occupied_repo}/prior.txt"
(cd "$occupied_repo" && JJ_CONFIG='' jj describe -m 'prior work' >/dev/null)
(cd "$occupied_repo" && HARNESS_AUTOMATED=1 HARNESS_TEST_JJ_REPO='' run_harness codex review)
if (cd "$occupied_repo" && JJ_CONFIG='' jj log -r 'all()' --no-graph \
    -T 'description.first_line() ++ "\n"' | grep -Fxq 'prior work') \
    && [[ -f "${occupied_repo}/prior.txt" ]]; then
    pass 'review-only run preserves an occupied prior jj change'
else
    fail 'review-only run preserves an occupied prior jj change'
fi

home="${tmp}/home"
versions="${home}/.local/share/claude/versions"
mkdir -p "$versions"
cp "${fake_bin}/claude" "${versions}/2.1.100"
sleep 1
printf '%s\n' partial > "${versions}/2.1.200"
chmod 644 "${versions}/2.1.200"
: > "$HARNESS_TEST_LOG"
HOME="$home" PATH="/opt/homebrew/bin:/usr/bin:/bin" SESSION_SYNC="$session_sync" \
    "$RUNNER" claude --help >/dev/null 2>&1
wait_for_log 'capture args='
assert_log_contains 'command=2.1.100 args=--help' 'a Claude download in progress does not hide the installed version'

HOME="$home" PATH="/usr/bin:/bin" "$RUNNER" grok --help >/dev/null 2>"${tmp}/absent-provider.err"
absent_status=$?
if [[ "$absent_status" -eq 127 ]] && grep -q 'grok is not installed' "${tmp}/absent-provider.err"; then
    pass 'an absent provider exits 127 with its name'
else
    fail 'an absent provider exits 127 with its name'
fi

if (( failures > 0 )); then
    echo "${failures} test(s) failed"
    exit 1
fi

echo 'All agent-run tests passed'
