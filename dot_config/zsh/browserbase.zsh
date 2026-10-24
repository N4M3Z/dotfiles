# Export the Browserbase key for the `browse` CLI and Stagehand scripts.
#
# The key lives in ~/.env as BROWSERBASE_API_KEY=bb_live_..., copied there
# from Proton Pass. The key alone resolves the default project, so no
# BROWSERBASE_PROJECT_ID is needed.
#
# This file reads only that one value from ~/.env.
# Sourcing the complete file would expose unrelated secrets to each shell.

[[ -r "${HOME}/.env" ]] || return 0

() {
    local value
    value="$(grep '^BROWSERBASE_API_KEY=' "${HOME}/.env" 2>/dev/null | cut -d= -f2-)"
    [[ -n "${value}" ]] && export BROWSERBASE_API_KEY="${value}"
}
