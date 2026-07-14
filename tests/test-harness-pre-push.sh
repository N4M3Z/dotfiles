#!/bin/bash
# Regression tests for WIP and harness-attribution push gates.
# Source: https://github.com/N4M3Z/dotfiles

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
HOOK="${ROOT}/.githooks/pre-push"
failures=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-pre-push.XXXXXX")"
trap 'command rm -rf "$tmp"' EXIT
repo="${tmp}/repo"
bin="${tmp}/bin"
mkdir -p "$repo" "$bin"
git -C "$repo" init -q -b main
empty_tree=$(git -C "$repo" mktree </dev/null)
wip_sha=$(
    printf '%s\n' 'WIP: Codex session fixture' \
        | GIT_AUTHOR_NAME='Fixture User' GIT_AUTHOR_EMAIL='fixture@example.invalid' \
            GIT_COMMITTER_NAME='Fixture User' GIT_COMMITTER_EMAIL='fixture@example.invalid' \
            git -C "$repo" commit-tree "$empty_tree"
)
git -C "$repo" update-ref refs/heads/main "$wip_sha"
if printf 'refs/heads/main %s refs/heads/main %040d\n' "$wip_sha" 0 \
    | (cd "$repo" && PATH="/usr/bin:/bin" "$HOOK" origin) >/dev/null 2>&1; then
    fail 'pre-push rejects harness WIP descriptions'
else
    pass 'pre-push rejects harness WIP descriptions'
fi

plain_sha=$(
    printf '%s\n' 'material change without attribution' \
        | GIT_AUTHOR_NAME='Fixture User' GIT_AUTHOR_EMAIL='fixture@example.invalid' \
            GIT_COMMITTER_NAME='Fixture User' GIT_COMMITTER_EMAIL='fixture@example.invalid' \
            git -C "$repo" commit-tree "$empty_tree" -p "$wip_sha"
)
git -C "$repo" update-ref refs/heads/main "$plain_sha"
expected='Co-authored-by: Codex / gpt-5.5 <N4M3Z@users.noreply.github.com>'
if printf 'refs/heads/main %s refs/heads/main %s\n' "$plain_sha" "$wip_sha" \
    | (cd "$repo" && HARNESS_EXPECTED_COAUTHOR="$expected" \
        PATH="/usr/bin:/bin" "$HOOK" origin) >/dev/null 2>&1; then
    fail 'pre-push rejects a missing expected harness trailer'
else
    pass 'pre-push rejects a missing expected harness trailer'
fi

attributed_sha=$(
    printf '%s\n\n%s\n' 'material attributed change' "$expected" \
        | GIT_AUTHOR_NAME='Fixture User' GIT_AUTHOR_EMAIL='fixture@example.invalid' \
            GIT_COMMITTER_NAME='Fixture User' GIT_COMMITTER_EMAIL='fixture@example.invalid' \
            git -C "$repo" commit-tree "$empty_tree" -p "$plain_sha"
)
git -C "$repo" update-ref refs/heads/main "$attributed_sha"
# shellcheck disable=SC2016 # ENTIRE_STDIN_LOG expands in the generated fake.
printf '%s\n' \
    '#!/bin/bash' \
    'cat > "$ENTIRE_STDIN_LOG"' \
    'exit 0' \
    > "${bin}/entire"
chmod +x "${bin}/entire"
export ENTIRE_STDIN_LOG="${tmp}/entire-stdin.log"
if printf 'refs/heads/main %s refs/heads/main %s\n' "$attributed_sha" "$plain_sha" \
    | (cd "$repo" && HARNESS_EXPECTED_COAUTHOR="$expected" \
        PATH="${bin}:/usr/bin:/bin" "$HOOK" origin) >/dev/null 2>&1; then
    pass 'pre-push accepts an attributed harness revision'
else
    fail 'pre-push accepts an attributed harness revision'
fi
if grep -Fq "$attributed_sha" "$ENTIRE_STDIN_LOG"; then
    pass 'pre-push forwards original refs to Entire'
else
    fail 'pre-push forwards original refs to Entire'
fi

if (( failures > 0 )); then
    echo "${failures} test(s) failed"
    exit 1
fi

echo 'All harness pre-push tests passed'
