# Export the Browserbase key for the `browse` CLI and Stagehand scripts.
#
# The key comes from the owner's secretspec store, the login Keychain
# (runedeck/provision PROV-0028), as BROWSERBASE_API_KEY. The key alone
# resolves the default project, so no BROWSERBASE_PROJECT_ID is needed.
#
# Only an interactive shell reads the store, and only when it has no key yet:
# a nested shell keeps its parent's key, and a script or a job makes no
# Keychain call. When the read fails, the shell starts without the key, and
# secretspec's error text is not shown.

[[ -o interactive ]] || return 0
[[ -n "${BROWSERBASE_API_KEY:-}" ]] && return 0
(( $+commands[secretspec] )) || return 0

() {
    # A trace (zsh -x) prints each expanded value, so it stays off in here.
    setopt local_options no_xtrace
    # The copy of the manifest that runedeck/provision publishes.
    local manifest="${BROWSERBASE_SECRETSPEC:-${HOME}/.config/provision/secretspec.toml}" value
    [[ -r "${manifest}" ]] || return 0
    value="$(command secretspec get BROWSERBASE_API_KEY --file "${manifest}" --profile owner \
        --reason "shell: the Browserbase key for the browse CLI" 2>/dev/null)" || return 0
    [[ -n "${value}" ]] && export BROWSERBASE_API_KEY="${value}"
}
