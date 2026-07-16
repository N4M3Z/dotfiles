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

# run_onchange_after_brew.sh.tmpl hashes the provisioning Brewfile at render
# time; only the path needs to exist for rendering, not real content.
BREWFILE_DIR="${HOME}/Developer/N4M3Z/forge-provision/manifests"
mkdir -p "${BREWFILE_DIR}"
[[ -f "${BREWFILE_DIR}/Brewfile" ]] || touch "${BREWFILE_DIR}/Brewfile"

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
done < <(find "${SOURCE_DIR}" -name '*.tmpl' -not -path '*/.git/*' | sort)

if [[ ${failures} -gt 0 ]]; then
    echo "validate-templates: ${failures} failure(s)"
    exit 1
fi
echo "validate-templates: all templates render, all modify scripts survive empty stdin"
