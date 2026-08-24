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

# The data config is written directly rather than produced by `chezmoi init`.
# init matches seeds against prompt text, so seeding here would pin this suite to
# the exact wording of six multi-line questions and break every time one is
# reworded. Writing the data keeps the suite testing what it is for, which is
# whether templates render for somebody who is not the author.
#
# What that trades away: the prompt flow in .chezmoi.toml.tmpl is not exercised,
# because chezmoi reads answers from /dev/tty and prompts without a default
# cannot be satisfied headlessly. assert_config_keys below covers the part that
# can regress silently, namely which data keys the config is expected to define.
seed_config() {
    local class="$1" config="$2" work_email="$3" work_host="$4"
    {
        printf '[data]\n'
        printf '    name = "Test Person"\n'
        printf '    email = "test@users.noreply.github.com"\n'
        printf '    workEmail = "%s"\n' "${work_email}"
        printf '    workGitHost = "%s"\n' "${work_host}"
        printf '    githubUser = "testuser"\n'
        printf '    machine = "%s"\n' "${class}"
    } > "${config}"
}

# Every key the suite supplies must be one the config template also defines, and
# the reverse, so a key added to one and not the other is caught here instead of
# as a rendering failure on somebody's first install.
assert_config_keys() {
    local template="${SOURCE_DIR}/.chezmoi.toml.tmpl" key
    for key in name email workEmail workGitHost githubUser machine; do
        if ! grep -q "^    ${key} = " "${template}"; then
            echo "FAIL config keys: .chezmoi.toml.tmpl does not define ${key}"
            failures=$((failures + 1))
        fi
    done
    while read -r key; do
        case "${key}" in
            name|email|workEmail|workGitHost|githubUser|machine) ;;
            *)
                echo "FAIL config keys: .chezmoi.toml.tmpl defines ${key}, which this suite does not seed"
                failures=$((failures + 1))
                ;;
        esac
    done < <(grep -oE '^    [a-zA-Z]+ = ' "${template}" | awk '{print $1}')
}

check_class() {
    local class="$1" config="${WORKDIR}/${1}.toml"

    if ! seed_config "${class}" "${config}" "${2}" "${3}"; then
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
            while IFS= read -r leaked; do printf '    %s\n' "${leaked}"; done <<< "${foreign_home}"
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
assert_config_keys
check_class work "work@example.com" "gitlab.example.com"
check_class personal "" ""

if [[ ${failures} -gt 0 ]]; then
    echo "validate-templates: ${failures} failure(s)"
    exit 1
fi
echo "validate-templates: every template renders for both machine classes, and all modify scripts survive empty stdin"
