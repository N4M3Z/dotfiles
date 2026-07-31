#!/bin/bash
# Render every chezmoi template against synthetic machine data and execute every
# modify_ script with empty stdin, the state chezmoi produces for a target that
# does not exist yet.
#
# The data is seeded rather than taken from this machine's config, which is the
# point: these dotfiles must render for somebody who is not their author. Both
# machine classes are exercised, because a template that only works on the
# authoring class is the failure this suite exists to catch.
#
# Caught here historically: a bare template directive inside a comment crashing
# apply, a policy merge that could not handle an absent live config, a literal
# home directory from the authoring machine, and a hash call that failed
# rendering when the hashed file was missing.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-validate.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

failures=0
index=0

# Prompt strings are identical to their data keys, which is what makes these
# seeds work; see the comment in .chezmoi.toml.tmpl.
seed_config() {
    local class="$1" config="$2" work_email="$3"
    chezmoi init --source "${SOURCE_DIR}" --config "${config}" \
        --destination "${WORKDIR}/home-${class}" --cache "${WORKDIR}/cache" \
        --promptString name="Test Person" \
        --promptString email="test@users.noreply.github.com" \
        --promptString workEmail="${work_email}" \
        --promptString githubUser="testuser" \
        --promptChoice machine="${class}" >/dev/null 2>&1
}

check_class() {
    local class="$1" config="${WORKDIR}/${1}.toml"

    if ! seed_config "${class}" "${config}" "${2}"; then
        echo "FAIL seed: could not generate config for ${class}"
        failures=$((failures + 1))
        return
    fi
    echo "-- machine class: ${class}"

    while IFS= read -r template; do
        relative="${template#"${SOURCE_DIR}"/}"

        # Prompt functions only exist while chezmoi generates its own config, so
        # the config template is exercised by seed_config above, not here.
        [[ "${relative}" == ".chezmoi.toml.tmpl" ]] && continue

        index=$((index + 1))
        rendered="${WORKDIR}/rendered-${index}"

        if ! chezmoi execute-template --source "${SOURCE_DIR}" --config "${config}" \
                < "${template}" > "${rendered}" 2> "${rendered}.err"; then
            echo "FAIL render (${class}): ${relative}"
            cat "${rendered}.err"
            failures=$((failures + 1))
            continue
        fi
        echo "ok render (${class}): ${relative}"

        # A literal home directory from the authoring machine renders fine and
        # then breaks wherever it deploys, and the tools that read these files
        # report the bad path only when first used.
        foreign_home=$(grep -oE '(/Users|/home)/[A-Za-z0-9._-]+' "${rendered}" \
            | grep -vxF "${HOME}" | sort -u || true)
        if [[ -n "${foreign_home}" ]]; then
            echo "FAIL foreign home path (${class}): ${relative}"
            echo "${foreign_home}" | sed 's/^/    /'
            failures=$((failures + 1))
        fi

        if [[ "$(basename "${template}")" == modify_* ]]; then
            if printf '' | bash "${rendered}" > "${rendered}.out" 2> "${rendered}.merr" \
                    && [[ -s "${rendered}.out" ]]; then
                echo "ok modify (${class}, empty stdin): ${relative}"
            else
                echo "FAIL modify (${class}, empty stdin): ${relative}"
                cat "${rendered}.merr"
                failures=$((failures + 1))
            fi
        fi
    done < <(find "${SOURCE_DIR}" -name '*.tmpl' -not -path '*/.git/*' | sort)
}

# A work machine sets workEmail so the per-forge git include renders; a personal
# machine leaves it blank so the include is omitted entirely.
check_class work "work@example.com"
check_class personal ""

if [[ ${failures} -gt 0 ]]; then
    echo "validate-templates: ${failures} failure(s)"
    exit 1
fi
echo "validate-templates: every template renders for both machine classes, and all modify scripts survive empty stdin"
