#!/bin/bash
# Grok's sandbox must close every path that Claude Code closes, and Grok's
# default profile must be a custom one.
#
# Claude turns its sandbox denyRead list and its Read(...) deny rules into
# kernel denies. Grok checks Claude's rules against its own tools and against
# the paths a shell command names, but a program that opens a file itself gets
# past that check. The profile's deny list is the only barrier for every
# process, so a path that is missing there is readable to a Grok command.
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
# chezmoi produces for a target that does not exist yet. The optional second
# argument is a live file to feed in instead.
run_modify() {
    render "$1" > "${WORKDIR}/modify.sh" || return 1
    printf '%s' "${2:-}" | bash "${WORKDIR}/modify.sh"
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

# Grok must read its own login files at startup, so a kernel deny would stop
# it from signing in. A permission deny keeps Grok's tools out of them.
token_gaps=$(jq -r '
    ["Read(~/.grok/auth.json)", "Read(~/.grok/mcp_credentials.json)"]
    - (.permission.deny // []) | .[]
' "${WORKDIR}/grok.json") || exit 1
if [[ -n "${token_gaps}" ]]; then
    echo "FAIL grok tools can read grok's own login files:"
    echo "${token_gaps}" | sed 's/^/    /'
    failures=$((failures + 1))
else
    echo "ok grok tools cannot read grok's login or MCP tokens"
fi

# Grok saves an always-approve choice in ui.yolo, and the next session starts
# in yolo. Each apply resets it, and keeps the keys that grok writes itself.
live_config=$'[ui]\nyolo = true\n\n[session]\nlast_model = "kept"\n'
run_modify dot_grok/modify_private_config.toml.tmpl "${live_config}" \
    | yq -p=toml -o=json '.' - > "${WORKDIR}/grok-live.json" || exit 1
if jq -e '.ui.yolo == false' "${WORKDIR}/grok.json" > /dev/null \
        && jq -e '.ui.yolo == false and .session.last_model == "kept"' \
            "${WORKDIR}/grok-live.json" > /dev/null; then
    echo "ok grok apply resets a saved yolo choice"
else
    echo "FAIL grok apply keeps a saved yolo choice, or drops grok's own keys"
    failures=$((failures + 1))
fi

# The reset must not become a lock. Only requirements.toml can lock yolo, so
# the source must manage neither that file nor the bypass switch.
if ! lock_files=$(find "${SOURCE_DIR}/dot_grok" -name '*requirements.toml*'); then
    echo "FAIL cannot scan Grok requirement files" >&2
    exit 1
fi
lock_keys=$(grep -rl --exclude-dir=.git --exclude-dir=.jj --exclude-dir=.workspaces \
    --exclude=test-grok-sandbox.sh 'disable_bypass_permissions_mode' "${SOURCE_DIR}")
lock_keys_status=$?
if [[ ${lock_keys_status} -gt 1 ]]; then
    echo "FAIL cannot scan the source for the bypass switch" >&2
    exit 1
fi
if [[ -n "${lock_files}${lock_keys}" ]]; then
    echo "FAIL the source locks grok yolo:"
    printf '%s\n%s\n' "${lock_files}" "${lock_keys}" | sed '/^$/d; s/^/    /'
    failures=$((failures + 1))
else
    echo "ok /yolo stays available: no requirements.toml and no bypass switch"
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-grok-sandbox: ${failures} failure(s)"
    exit 1
fi
echo "test-grok-sandbox: grok keeps Claude's denied paths closed"
