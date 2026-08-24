#!/bin/bash
# Assert the computed chezmoi target state deploys only intended paths into
# $HOME. An unprefixed source path silently becomes a home-directory
# deployment, and chezmoi reports it only on the next apply, so repo-internal
# artifacts (governance files, schemas, CI material) must be caught here.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-target-state.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

# Every top-level destination the source tree is allowed to produce. A new
# legitimate root is a deliberate, reviewed addition to this list.
allowed=(
    .claude
    .codex
    .config
    .gemini
    .gitconfig
    .gnupg
    .grok
    .local
    .macos
    .p10k.zsh
    .specstory
    .ssh
    .zpreztorc
    .zprofile
    .zsh
    .zshenv
    .zshrc
    sd
)

# Repo-internal artifacts that must never enter the target state, asserted
# by name so a broken allowlist cannot mask them.
forbidden=(
    CODEOWNERS
    KEYS
    schemas
    INSTALL.md
    CONTRIBUTING.md
)

if ! roots=$(chezmoi --source "$SOURCE_DIR" --destination "$WORKDIR/home" \
        managed --exclude scripts 2> "$WORKDIR/managed.err" \
        | awk -F/ '{print $1}' | sort -u); then
    echo "FAIL chezmoi managed:"
    cat "$WORKDIR/managed.err"
    exit 1
fi

failures=0

for name in "${forbidden[@]}"; do
    if grep -qxF "$name" <<< "$roots"; then
        echo "FAIL forbidden target: $name deploys into \$HOME"
        failures=$((failures + 1))
    fi
done

while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    found=0
    for name in "${allowed[@]}"; do
        [[ "$root" == "$name" ]] && { found=1; break; }
    done
    if [[ "$found" -eq 0 ]]; then
        echo "FAIL unexpected target root: $root (add to .chezmoiignore, or to the allowlist in ${BASH_SOURCE[0]##*/} if intended)"
        failures=$((failures + 1))
    fi
done <<< "$roots"

if [[ "$failures" -gt 0 ]]; then
    echo "target-state validation: $failures failure(s)"
    exit 1
fi

echo "ok target state: only intended roots deploy"
