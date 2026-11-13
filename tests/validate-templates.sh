#!/bin/bash
# Render every chezmoi template and execute every modify_ script with empty
# stdin, the state chezmoi produces for a target that does not exist yet.
# Catches template parse errors (a bare directive in a comment once crashed
# apply) and merge pipelines that cannot handle an absent live config.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-validate.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

failures=0
index=0

while IFS= read -r template; do
    index=$((index + 1))
    relative="${template#"${SOURCE_DIR}"/}"
    rendered="${WORKDIR}/rendered-${index}"

    if ! chezmoi execute-template --source "${SOURCE_DIR}" \
            < "${template}" > "${rendered}" 2> "${rendered}.err"; then
        echo "FAIL render: ${relative}"
        cat "${rendered}.err"
        failures=$((failures + 1))
        continue
    fi
    echo "ok render: ${relative}"

    # A literal home directory from the authoring machine renders fine and then
    # breaks wherever it deploys, and the tools that read these files report the
    # bad path only when first used. Anything under /Users or /home that is not
    # this machine's home is such a leak.
    foreign_home=$(grep -oE '(/Users|/home)/[A-Za-z0-9._-]+' "${rendered}" \
        | grep -vxF "${HOME}" | sort -u || true)
    if [[ -n "${foreign_home}" ]]; then
        echo "FAIL foreign home path: ${relative}"
        echo "${foreign_home}" | sed 's/^/    /'
        failures=$((failures + 1))
    fi

    if [[ "$(basename "${template}")" == modify_* ]]; then
        if printf '' | bash "${rendered}" > "${rendered}.out" 2> "${rendered}.merr" \
                && [[ -s "${rendered}.out" ]]; then
            echo "ok modify (empty stdin): ${relative}"
        else
            echo "FAIL modify (empty stdin): ${relative}"
            cat "${rendered}.merr"
            failures=$((failures + 1))
        fi
    fi
# .chezmoi.toml.tmpl reads the password store, which CI and agent sandboxes
# cannot reach; tests/test-private-data.sh renders it against a stub pass.
# .workspaces holds jj workspaces: full copies of other changes, some stale.
done < <(find "${SOURCE_DIR}" -name '*.tmpl' -not -name '.chezmoi.toml.tmpl' -not -path '*/.git/*' \
    -not -path "${SOURCE_DIR}/.workspaces/*" | sort)

# This repository is public. A literal macOS home path in a tracked file shows
# the author's folder layout and fits no other machine. Policy data writes ~/
# and the template fills in the home folder. docs/ keeps its records as written.
if git -C "${SOURCE_DIR}" rev-parse --git-dir > /dev/null 2>&1; then
    literal_home=$(git -C "${SOURCE_DIR}" ls-files -z -- . ':!docs' \
        | (cd "${SOURCE_DIR}" && xargs -0 grep -nIE '/Users/[A-Za-z0-9._-]+' -- 2>/dev/null) \
        || true)
    if [[ -n "${literal_home}" ]]; then
        echo "FAIL literal home path in a tracked file:"
        while IFS= read -r hit; do printf '    %s\n' "${hit}"; done <<< "${literal_home}"
        failures=$((failures + 1))
    else
        echo "ok no literal home path in a tracked file"
    fi
fi

if [[ ${failures} -gt 0 ]]; then
    echo "validate-templates: ${failures} failure(s)"
    exit 1
fi
echo "validate-templates: all templates render, all modify scripts survive empty stdin"
