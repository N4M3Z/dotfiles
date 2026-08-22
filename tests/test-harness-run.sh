#!/bin/bash
# Regression tests for transparent cross-harness launch policy.
# Source: https://github.com/N4M3Z/dotfiles

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
RUNNER="${ROOT}/dot_local/bin/executable_harness-run"
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
            'printf "jj_attended=%s\n" "${JJ_ATTENDED:-}" >> "$HARNESS_TEST_LOG"' \
            'printf "gh_token=%s\n" "${GH_TOKEN:+set}" >> "$HARNESS_TEST_LOG"' \
            'printf "github_token=%s\n" "${GITHUB_TOKEN:+set}" >> "$HARNESS_TEST_LOG"' \
            'agent_config="${JJ_CONFIG##*:}"' \
            'if grep -Fq "sign-on-push = false" "$agent_config"; then' \
            '    printf "agent_sign_on_push=false\n" >> "$HARNESS_TEST_LOG"' \
            'fi' \
            'if [[ -n "${HARNESS_TEST_JJ_REPO:-}" ]]; then' \
            '    cd "$HARNESS_TEST_JJ_REPO" || exit 1' \
            '    printf "%s\n" material > material.txt' \
            '    jj status >/dev/null' \
            'fi' \
            'exit "${HARNESS_FAKE_STATUS:-0}"' \
            > "${bin}/${name}"
        chmod +x "${bin}/${name}"
    done
}

run_harness() {
    : > "$HARNESS_TEST_LOG"
    if [[ "${HARNESS_TEST_DEBUG:-0}" == '1' ]]; then
        HARNESS_REAL_BIN_DIR="$fake_bin" SESSION_SYNC="$session_sync" "$RUNNER" "$@"
    else
        HARNESS_REAL_BIN_DIR="$fake_bin" SESSION_SYNC="$session_sync" \
            "$RUNNER" "$@" >/dev/null 2>&1
    fi
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-run-tests.XXXXXX")"
trap 'command rm -rf "$tmp"' EXIT
fake_bin="${tmp}/bin"
session_sync="${tmp}/session-sync"
export HARNESS_TEST_LOG="${tmp}/harness.log"
export HARNESS_CAPTURE_DEBT_DIR="${tmp}/debt"
make_fake_harnesses "$fake_bin"
cd "$tmp" || exit 1

# shellcheck disable=SC2016 # CAPTURE_STATUS expands when the fake hook runs.
printf '%s\n' '#!/bin/bash' 'exit "${CAPTURE_STATUS:-0}"' > "$session_sync"
chmod +x "$session_sync"

run_harness claude --help
assert_log_contains 'command=claude args=--help' 'Claude wrapper reaches the real binary without recursion'
assert_log_excludes '--model' 'interactive Claude leaves the model default untouched'

run_harness codex review
assert_log_contains 'command=codex args=review' 'interactive Codex preserves arguments'
assert_log_excludes '--model' 'interactive Codex leaves the model default untouched'

JJ_ATTENDED=1 GH_TOKEN=runewright GITHUB_TOKEN=runewright run_harness codex review
assert_log_excludes 'jj_attended=1' 'agent launcher removes the attended marker'
assert_log_contains 'agent_sign_on_push=false' 'agent launcher disables Jujutsu push signing'
assert_log_excludes 'gh_token=set' 'agent launcher removes GH_TOKEN'
assert_log_excludes 'github_token=set' 'agent launcher removes GITHUB_TOKEN'

run_harness antigravity --help
assert_log_contains 'command=agy args=--sandbox --help' 'Antigravity always enables its native sandbox'
assert_log_excludes '--model' 'interactive Antigravity leaves the model default untouched'

run_harness grok --help
assert_log_contains '--sandbox workspace' 'interactive Grok uses the workspace sandbox profile'
assert_log_excludes '--model' 'interactive Grok leaves the model default untouched'

run_harness opencode --help
assert_log_contains 'command=opencode args=--help' 'interactive OpenCode preserves arguments'
assert_log_excludes '--model' 'interactive OpenCode leaves the model default untouched'

HARNESS_AUTOMATED=1 run_harness claude -p scan
assert_log_contains '--model claude-fable-5' 'automated Claude pins Fable'

HARNESS_AUTOMATED=1 run_harness codex review
assert_log_contains '--sandbox read-only' 'automated Codex is read-only'
assert_log_contains '--ask-for-approval never' 'automated Codex cannot stall on approval'

HARNESS_AUTOMATED=1 run_harness antigravity -p scan
assert_log_contains 'Gemini\ 3.5\ Flash\ \(High\)' 'automated Antigravity pins Gemini 3.5 Flash High'

HARNESS_AUTOMATED=1 run_harness grok -p scan
assert_log_contains '--sandbox read-only' 'automated Grok is read-only'
assert_log_contains '--permission-mode dontAsk' 'automated Grok denies unapproved tools instead of prompting'

HARNESS_AUTOMATED=1 run_harness opencode run scan
assert_log_contains '--model proton-lumo/lumo-max' 'automated OpenCode pins Lumo Max'
assert_log_contains 'opencode_permission={"*":"deny"' 'automated OpenCode receives a non-interactive read-only override'

: > "$HARNESS_TEST_LOG"
if CAPTURE_STATUS=1 HARNESS_REAL_BIN_DIR="$fake_bin" SESSION_SYNC="$session_sync" \
    HARNESS_FAKE_STATUS=7 "$RUNNER" claude -p scan >/dev/null 2>&1; then
    fail 'provider failure status is preserved when capture also fails'
elif [[ "$?" -eq 7 ]]; then
    pass 'provider failure status is preserved when capture also fails'
else
    fail 'provider failure status is preserved when capture also fails'
fi
if find "$HARNESS_CAPTURE_DEBT_DIR" -type f -name 'claude-*.json' -print -quit \
    | grep -q .; then
    pass 'capture failure creates persisted retry debt'
else
    fail 'capture failure creates persisted retry debt'
fi

CAPTURE_STATUS=0 run_harness claude -p scan
if find "$HARNESS_CAPTURE_DEBT_DIR" -type f -name 'claude-*.json' -print -quit \
    | grep -q .; then
    fail 'successful native sweep clears recovered capture debt'
else
    pass 'successful native sweep clears recovered capture debt'
fi

if HARNESS_AUTOMATED=1 HARNESS_MODEL='bad"model' run_harness codex review; then
    fail 'unsafe custom model is rejected before jj attribution'
else
    pass 'unsafe custom model is rejected before jj attribution'
fi

jj_repo="${tmp}/jj-repo"
mkdir -p "$jj_repo"
git -C "$jj_repo" init -q -b main
(cd "$jj_repo" && JJ_CONFIG='' jj git init --colocate >/dev/null)
(cd "$jj_repo" && HARNESS_AUTOMATED=1 HARNESS_TEST_JJ_REPO="$jj_repo" run_harness codex review)
if git -C "$jj_repo" log -1 --format=%B \
    | grep -Fq 'Co-authored-by: Codex / gpt-5.5 <N4M3Z@users.noreply.github.com>'; then
    pass 'automated harness material changes receive a native jj coauthor trailer'
else
    fail 'automated harness material changes receive a native jj coauthor trailer'
fi
if git -C "$jj_repo" log -1 --format=%s | grep -Fq 'chore: Codex automated session'; then
    pass 'automated harness material change is closed with a final description'
else
    fail 'automated harness material change is closed with a final description'
fi

empty_repo="${tmp}/empty-jj-repo"
mkdir -p "$empty_repo"
git -C "$empty_repo" init -q -b main
(cd "$empty_repo" && JJ_CONFIG='' jj git init --colocate >/dev/null)
before_empty=$(cd "$empty_repo" && JJ_CONFIG='' jj log -r 'all()' --no-graph -T 'change_id ++ "\n"' | wc -l | tr -d ' ')
(cd "$empty_repo" && HARNESS_AUTOMATED=1 HARNESS_TEST_JJ_REPO='' run_harness codex review)
after_empty=$(cd "$empty_repo" && JJ_CONFIG='' jj log -r 'all()' --no-graph -T 'change_id ++ "\n"' | wc -l | tr -d ' ')
if [[ "$before_empty" == "$after_empty" ]]; then
    pass 'review-only automated run abandons its empty claimed revision'
else
    fail 'review-only automated run abandons its empty claimed revision'
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

normal_repo="${tmp}/normal-jj-repo"
mkdir -p "$normal_repo"
git -C "$normal_repo" init -q -b main
(cd "$normal_repo" && JJ_CONFIG='' jj git init --colocate >/dev/null)
printf '%s\n' normal > "${normal_repo}/normal.txt"
(cd "$normal_repo" && JJ_CONFIG='' jj describe -m 'normal shell change' >/dev/null)
(cd "$normal_repo" && JJ_CONFIG='' jj new >/dev/null)
if git -C "$normal_repo" log -1 --format=%B | grep -Fq 'Co-authored-by:'; then
    fail 'normal shell work has no harness coauthor trailer'
else
    pass 'normal shell work has no harness coauthor trailer'
fi

if (( failures > 0 )); then
    echo "${failures} test(s) failed"
    exit 1
fi

echo 'All harness-run tests passed'
