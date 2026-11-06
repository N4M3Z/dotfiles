#!/bin/bash
# Grok's sandbox must close every path that Claude Code closes, and Grok's
# default profile must be a custom one.
#
# Claude turns its sandbox denyRead list and its Read(...) deny rules into
# kernel denies. Grok applies Claude's rules to its own tools only, so for a
# Grok shell command the profile's deny list is the only barrier. A path that
# is missing there is readable to the shell.
#
# A built-in grok profile keeps running without enforcement when the kernel
# refuses it. A custom profile refuses to start instead. So the default
# profile must be one that sandbox.toml defines.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/grok-sandbox.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

render() {
    chezmoi execute-template --source "${SOURCE_DIR}" < "${SOURCE_DIR}/$1"
}

# A modify_ script prints the whole target file. Empty stdin is the state
# chezmoi produces for a target that does not exist yet.
run_modify() {
    render "$1" > "${WORKDIR}/modify.sh" || return 1
    printf '' | bash "${WORKDIR}/modify.sh"
}

render dot_grok/private_sandbox.toml.tmpl \
    | yq -p=toml -o=json '.' - > "${WORKDIR}/sandbox.json" || exit 1
run_modify dot_grok/modify_private_config.toml.tmpl \
    | yq -p=toml -o=json '.' - > "${WORKDIR}/grok.json" || exit 1
run_modify dot_claude/modify_private_settings.json.tmpl \
    > "${WORKDIR}/claude.json" || exit 1

failures=0

# Write each Claude path the way the grok template writes it: ~/ is the home,
# a leading // marks an absolute path, ./ becomes a relative entry, and a
# trailing /** on a literal path becomes the directory itself.
missing=$(jq -r --arg home "${HOME}" --slurpfile sandbox "${WORKDIR}/sandbox.json" '
    def grok_path:
        (if startswith("~/") then $home + .[1:]
         elif startswith("//") then .[1:]
         elif startswith("./") then .[2:]
         else . end)
        | if endswith("/**") and ((.[:-3] | test("[*?\\[]")) | not)
          then .[:-3] else . end;
    ([.sandbox.filesystem.denyRead[]]
        + [.permissions.deny[] | select(startswith("Read(") and endswith(")")) | .[5:-1]])
    | map(grok_path) | unique as $expected
    | $sandbox[0].profiles | to_entries[]
    | .key as $profile
    | ($expected - (.value.deny // [])) as $gap
    | $gap[] | "\($profile): \(.)"
' "${WORKDIR}/claude.json") || exit 1

if [[ -n "${missing}" ]]; then
    echo "FAIL grok profiles leave paths open that Claude denies:"
    echo "${missing}" | sed 's/^/    /'
    failures=$((failures + 1))
else
    echo "ok grok profiles deny every path Claude denies"
fi

profile=$(jq -r '.sandbox.profile // ""' "${WORKDIR}/grok.json")
case "${profile}" in
    ""|off|workspace|read-only|strict|devbox)
        echo "FAIL grok default profile '${profile}' is not a custom profile"
        failures=$((failures + 1))
        ;;
    *)
        if jq -e --arg profile "${profile}" '.profiles | has($profile)' \
                "${WORKDIR}/sandbox.json" > /dev/null; then
            echo "ok grok default profile '${profile}' is defined in sandbox.toml"
        else
            echo "FAIL grok default profile '${profile}' is missing from sandbox.toml"
            failures=$((failures + 1))
        fi
        ;;
esac

if jq -e '.ui.permission_mode == "auto" and .auto_mode.enabled == true' \
        "${WORKDIR}/grok.json" > /dev/null; then
    echo "ok grok starts in auto mode"
else
    echo "FAIL grok does not start in auto mode"
    failures=$((failures + 1))
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-grok-sandbox: ${failures} failure(s)"
    exit 1
fi
echo "test-grok-sandbox: grok keeps Claude's denied paths closed"
