#!/bin/bash
# Check the just command tree (~/.config/just, PROV-0025): the justfile and
# every module parse, every executable has a recipe and every recipe an
# executable, each recipe execs its own script, and no caller still names
# the retired ~/.sd tree.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-just.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT
failures=0

command -v just >/dev/null 2>&1 || { echo "validate-just-tree: just is not installed"; exit 1; }

# Deploy only the tree into a scratch home, so chezmoi strips the
# executable_ prefix and sets the modes the recipes rely on. The empty
# config keeps the password-store config template out of the run.
home="${WORKDIR}/home"
mkdir -p "${home}/.config"
: > "${WORKDIR}/chezmoi.toml"
if ! chezmoi --config "${WORKDIR}/chezmoi.toml" --persistent-state "${WORKDIR}/state.boltdb" \
        --source "${SOURCE_DIR}" --destination "${home}" \
        apply --force --exclude scripts,externals "${home}/.config/just" \
        > "${WORKDIR}/apply.log" 2>&1; then
    echo "FAIL deploy: chezmoi apply of .config/just"
    cat "${WORKDIR}/apply.log"
    exit 1
fi
tree="${home}/.config/just"
justfile="${tree}/justfile"

if summary=$(just --justfile "${justfile}" --summary 2> "${WORKDIR}/parse.err"); then
    echo "ok parse: justfile and every module"
else
    echo "FAIL parse: justfile"
    cat "${WORKDIR}/parse.err"
    exit 1
fi

# Recipes come in path form (tmux::turn::review); executables in the tree
# are tmux/turn/review. hooks/ holds dispatcher parts, which have no recipe.
# shellcheck disable=SC2086 # the summary is one space-separated line
printf '%s\n' ${summary} | sort > "${WORKDIR}/recipes"
(cd "${tree}" && find . -type f -perm -u+x -not -path './hooks/*' \
    | sed 's#^\./##; s#/#::#g' | sort) > "${WORKDIR}/scripts"
if diff "${WORKDIR}/recipes" "${WORKDIR}/scripts" > "${WORKDIR}/parity"; then
    echo "ok parity: $(wc -l < "${WORKDIR}/recipes" | tr -d ' ') recipes, one per executable"
else
    echo "FAIL parity (< recipe without executable, > executable without recipe)"
    cat "${WORKDIR}/parity"
    failures=$((failures + 1))
fi

# Each recipe must evaluate to an exec of the script beside it.
while IFS= read -r recipe; do
    relative="${recipe//::/\/}"
    if ! just --justfile "${justfile}" --dry-run "${recipe}" 2>&1 \
            | grep -qF "exec \"${tree}/${relative}\" "; then
        echo "FAIL resolve: ${recipe} does not exec ${relative}"
        failures=$((failures + 1))
    fi
done < "${WORKDIR}/recipes"
[[ ${failures} -eq 0 ]] && echo "ok resolve: every recipe execs its own script"

# No tracked file names the retired tree or its dispatcher. The patterns are
# built from pieces so this test does not match itself. docs/ keeps its
# history; .chezmoiremove and the Claude and Codex modify scripts carry the old
# path on purpose, to remove it and to repoint live hook entries.
old_tree='\.s''d/'
old_root='SD_''ROOT'
old_verb='\bs''d (tldr|agent|claude|github|openspec|tmux|zed|job|hook)\b'
stale=$(git -C "${SOURCE_DIR}" ls-files \
    | grep -v -e '^docs/' -e '^\.chezmoiremove$' -e 'modify_private_settings\.json\.tmpl$' \
        -e '^dot_codex/modify_private_config\.toml\.tmpl$' \
    | tr '\n' '\0' \
    | (cd "${SOURCE_DIR}" && xargs -0 grep -nIE "${old_tree}|${old_root}|${old_verb}" -- 2>/dev/null) \
    || true)
if [[ -n "${stale}" ]]; then
    echo "FAIL stale reference to the retired tree:"
    while IFS= read -r line; do printf '    %s\n' "${line}"; done <<< "${stale}"
    failures=$((failures + 1))
else
    echo "ok callers: no tracked file names the retired tree"
fi

if [[ ${failures} -gt 0 ]]; then
    echo "validate-just-tree: ${failures} failure(s)"
    exit 1
fi
echo "validate-just-tree: tree parses, recipes and scripts match, no stale callers"
