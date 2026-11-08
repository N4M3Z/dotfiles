#!/bin/bash
# Muse Code must start in a custom auto-review profile that closes every path
# Claude Code closes and allows the hosts Claude allows, and each apply must
# put that profile back as the default.
#
# Claude turns its sandbox denyRead list and its Read(...) deny rules into
# kernel denies. Muse turns a profile's filesystem deny rules into kernel
# denies for each shell command, so a path missing from the profile is
# readable to a Muse command. Muse refuses to start on a rule it cannot
# enforce, so on a host with muse installed the rendered settings must also
# start Muse cleanly.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/muse-sandbox.XXXXXX") || exit 1
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

run_modify dot_config/muse/modify_settings.json.tmpl > "${WORKDIR}/muse.json" || exit 1
run_modify dot_claude/modify_private_settings.json.tmpl > "${WORKDIR}/claude.json" || exit 1

failures=0
fail() {
    echo "FAIL $1"
    [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/    /'
    failures=$((failures + 1))
}

profile_id=$(jq -r '.permissions.default_profile // ""' "${WORKDIR}/muse.json")
jq '.permissions.profiles[.permissions.default_profile] // {}' "${WORKDIR}/muse.json" \
    > "${WORKDIR}/profile.json"

# Write each Claude path the way the muse template writes it: ~/ is the home,
# a leading // marks an absolute path, ./ goes under :workspace_roots, and a
# trailing /** on a literal path becomes the path itself. An absolute glob is
# checked against what it matches on this host, as the template expands it.
jq -r '
    ([.sandbox.filesystem.denyRead[]]
        + [.permissions.deny[] | select(startswith("Read(") and endswith(")")) | .[5:-1]])
    | unique[]
' "${WORKDIR}/claude.json" > "${WORKDIR}/claude-paths.txt" || exit 1
: > "${WORKDIR}/expected.txt"
while IFS= read -r path; do
    scope=absolute
    # The rule text holds a literal ~/, so the match must not expand it.
    # shellcheck disable=SC2088
    case "${path}" in
        "~/"*) path="${HOME}/${path#"~/"}" ;;
        //*) path="${path#/}" ;;
        ./*) path="${path#./}"; scope=workspace ;;
    esac
    literal="${path%/\*\*}"
    [[ "${literal}" == *[\*\?\[]* ]] || path="${literal}"
    if [[ "${scope}" == absolute && "${path}" == *[\*\?\[]* ]]; then
        while IFS= read -r match; do
            [[ -n "${match}" ]] && printf 'absolute\t%s\n' "${match}"
        done < <(compgen -G "${path%/\*\*}")
    else
        printf '%s\t%s\n' "${scope}" "${path}"
    fi
done < "${WORKDIR}/claude-paths.txt" >> "${WORKDIR}/expected.txt"

missing=$(while IFS=$'\t' read -r scope path; do
    if [[ "${scope}" == workspace ]]; then
        jq -e --arg p "${path}" '.filesystem[":workspace_roots"][$p] == "deny"' \
            "${WORKDIR}/profile.json" > /dev/null || echo "./${path}"
    else
        jq -e --arg p "${path}" '.filesystem[$p] == "deny"' \
            "${WORKDIR}/profile.json" > /dev/null || echo "${path}"
    fi
done < "${WORKDIR}/expected.txt")
if [[ -n "${missing}" ]]; then
    fail "the muse profile leaves paths open that Claude denies:" "${missing}"
else
    echo "ok the muse profile denies every path Claude denies"
fi

if jq -e --arg auth "${HOME}/.config/muse/auth.json" '.filesystem[$auth] == "deny"' \
        "${WORKDIR}/profile.json" > /dev/null; then
    echo "ok muse shell commands cannot read muse's stored login"
else
    fail "the muse profile leaves ~/.config/muse/auth.json readable"
fi

case "${profile_id}" in
    ""|:*)
        fail "muse default profile '${profile_id}' is not a custom profile"
        ;;
    *)
        if jq -e '.extends == ":auto-review"' "${WORKDIR}/profile.json" > /dev/null; then
            echo "ok muse starts in custom profile '${profile_id}' on top of :auto-review"
        else
            fail "muse profile '${profile_id}' is missing or does not extend :auto-review"
        fi
        ;;
esac

# The network rules mirror Claude's allowedDomains. Muse refuses a loopback
# name as a target, so loopback is limited to the trusted local service ports.
host_gaps=$(jq -r --slurpfile muse "${WORKDIR}/profile.json" '
    [.sandbox.network.allowedDomains[] | select(. != "localhost" and . != "127.0.0.1")]
    - [($muse[0].network.targets // {}) | to_entries[] | select(.value == "allow") | .key] | .[]
' "${WORKDIR}/claude.json") || exit 1
socket_gaps=$(jq -r --arg home "${HOME}" --slurpfile muse "${WORKDIR}/profile.json" '
    [.sandbox.network.allowUnixSockets[] | sub("^~/"; $home + "/")]
    - [($muse[0].network.unix_sockets // {}) | keys[]] | .[]
' "${WORKDIR}/claude.json") || exit 1
if [[ -n "${host_gaps}${socket_gaps}" ]]; then
    fail "the muse profile does not allow what Claude allows:" "${host_gaps}${socket_gaps:+$'\n'}${socket_gaps}"
elif ! jq -e '.network.mode == "proxy_only"' "${WORKDIR}/profile.json" > /dev/null; then
    fail "muse shell network is not proxy_only"
elif ! jq -e '(.network.local_ports | keys | sort) == ["11434", "31415", "5432"]' \
        "${WORKDIR}/profile.json" > /dev/null; then
    fail "muse loopback ports are not exactly Postgres, Ollama, and oMLX"
else
    echo "ok muse shell network goes through the proxy with Claude's hosts and the trusted ports"
fi

# The TUI picker saves its choice in default_profile, and a saved
# :unrestricted would start every session in yolo. Each apply resets it, keeps
# the keys Muse writes itself, and does not stack the managed hook entries.
live=$(jq -n --slurpfile rendered "${WORKDIR}/muse.json" '{
    schema_version: 1,
    tui: {verbose_output: "more"},
    permissions: {schema_version: 1, default_profile: ":unrestricted",
                  profiles: {mine: {extends: ":ask-me"}}},
    hooks: {PreToolUse: ($rendered[0].hooks.PreToolUse + [{matcher: "bash", hooks: [{type: "command", command: "/opt/mine"}]}])}
}')
run_modify dot_config/muse/modify_settings.json.tmpl "${live}" > "${WORKDIR}/muse-live.json" || exit 1
if jq -e --arg id "${profile_id}" --slurpfile rendered "${WORKDIR}/muse.json" '
        .permissions.default_profile == $id
        and .tui.verbose_output == "more"
        and .permissions.profiles.mine.extends == ":ask-me"
        and (.hooks.PreToolUse | length) == (($rendered[0].hooks.PreToolUse | length) + 1)
        and any(.hooks.PreToolUse[].hooks[]; .command == "/opt/mine")
    ' "${WORKDIR}/muse-live.json" > /dev/null; then
    echo "ok muse apply resets a saved :unrestricted default and keeps muse's own keys"
else
    fail "muse apply keeps a saved :unrestricted default, drops muse's keys, or stacks hooks"
fi

# The reset must not become a lock: `--yolo` stays available. Only Muse's
# enterprise policy plane can forbid a profile, so the source must not set one.
lock_keys=$(grep -rlE --exclude-dir=.git --exclude-dir=.jj --exclude-dir=.workspaces \
    --exclude=test-muse-sandbox.sh 'permission_profiles|capability_ceilings' "${SOURCE_DIR}")
if [[ -n "${lock_keys}" ]]; then
    fail "the source writes a muse policy plane that can lock yolo:" "${lock_keys}"
else
    echo "ok --yolo stays available: no muse policy plane in the source"
fi

# On a host with muse, start it once with the rendered settings in a scratch
# config home. The echo provider stays on this host. Muse names an unknown key,
# a bad hook, or a rule it cannot enforce at startup and refuses the profile.
MUSE=$(command -v muse)
if [[ -z "${MUSE}" ]]; then
    echo "skip muse is not installed, so the settings are not loaded"
else
    mkdir -p "${WORKDIR}/xdg/muse" "${WORKDIR}/ws"
    cp -f "${WORKDIR}/muse.json" "${WORKDIR}/xdg/muse/settings.json"
    muse_timeout=()
    if command -v timeout > /dev/null 2>&1; then
        muse_timeout=(timeout 120)
    elif command -v gtimeout > /dev/null 2>&1; then
        muse_timeout=(gtimeout 120)
    fi
    output=$(cd "${WORKDIR}/ws" && XDG_CONFIG_HOME="${WORKDIR}/xdg" "${muse_timeout[@]}" "${MUSE}" exec \
        --provider echo --no-session-log --disable-reminders probe 2>&1)
    code=$?
    problems=$(printf '%s\n' "${output}" \
        | grep -E 'ermission profile|unknown (key|field)|refusing run|Hooks: .*warning|UnsupportedEvent|MalformedConfig')
    # Muse quotes the path in literal backticks.
    # shellcheck disable=SC2016
    unreadable=$(printf '%s\n' "${problems}" | sed -n 's/^Named permission profiles are unavailable: unresolvable Unix socket path `\(.*\)`\.$/\1/p')
    socket_problem="Named permission profiles are unavailable: unresolvable Unix socket path \`${unreadable}\`."
    if [[ ${code} -eq 1 && -n "${unreadable}" && "${output}" == "${socket_problem}" \
        && ! -r "$(dirname "${unreadable}")" ]]; then
        # An agent sandbox around this test hides the socket's folder from Muse.
        echo "skip muse cannot resolve ${unreadable} here: its folder is unreadable in this sandbox"
    elif [[ ${code} -ne 0 || -n "${problems}" ]]; then
        fail "muse does not load the rendered settings (exit ${code}):" "${problems:-$(printf '%s\n' "${output}" | tail -n 5)}"
    else
        echo "ok muse loads the rendered settings and the profile"
    fi
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-muse-sandbox: ${failures} failure(s)"
    exit 1
fi
echo "test-muse-sandbox: muse keeps Claude's denied paths closed"
