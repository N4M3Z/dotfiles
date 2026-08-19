# Route supported CLI harnesses through CLIProxyAPI at 127.0.0.1:8317.
# CPA-Manager-Plus records requests that pass through this endpoint.
#
# Plain `codex` and Codex Desktop connect directly to OpenAI.
# `codex-proxy` selects CLIProxyAPI for one command with `--config`.
# Rune uses `codex-proxy` for all Codex calls.
#
#   cliproxy off      disable proxy launchers
#   cliproxy on       enable proxy launchers
#   cliproxy status   show routes and proxy health
#   noproxy <cmd>     run one command against vendor endpoints
#
# Harnesses use loopback, so they do not depend on Caddy or dnsmasq.
# Claude Code reads ANTHROPIC_BASE_URL from this shell.
# The Grok launcher reads the off flag and CLIPROXY_BYPASS.
# The Codex proxy launcher reads the off flag and overrides model_provider.
#
# This file reads only CLIPROXY values from ~/.env.
# Sourcing the complete file would expose unrelated secrets to each shell.

export CLIPROXY_URL="http://127.0.0.1:8317"
CLIPROXY_OFF_FLAG="${HOME}/.config/zsh/cliproxy.off"

[[ -r "${HOME}/.env" ]] || return 0

# Load keys for status checks and explicit proxy launchers.
() {
    local key value
    for key in CLIPROXY_API_KEY CLIPROXY_API_KEY_CODEX CLIPROXY_API_KEY_GEMINI CLIPROXY_MGMT_KEY; do
        value="$(grep "^${key}=" "${HOME}/.env" 2>/dev/null | cut -d= -f2-)"
        [[ -n "${value}" ]] && export "${key}=${value}"
    done
}

if [[ -z "${CLIPROXY_API_KEY}" ]]; then
    return 0
fi

unset GROK_CLI_CHAT_PROXY_BASE_URL

if [[ ! -e "${CLIPROXY_OFF_FLAG}" ]]; then
    # An unprefixed Claude model selects the highest-priority account.
    # Use `main/<model>` or `rune launch main@claude` for the main account.
    # Fill-first routing changes accounts only after a quota limit.
    # The main account remains available for direct Remote Control sessions.
    export ANTHROPIC_BASE_URL="${CLIPROXY_URL}"
    export ANTHROPIC_AUTH_TOKEN="${CLIPROXY_API_KEY}"
fi

# Run one command against the vendor endpoints without changing global state.
# CLIPROXY_BYPASS=1 tells `sd agent run` to skip its grok proxy injection.
noproxy() {
    env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN \
        CLIPROXY_BYPASS=1 "$@"
}

cliproxy() {
    case "${1:-}" in
        off)
            command touch "${CLIPROXY_OFF_FLAG}"
            unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN GROK_CLI_CHAT_PROXY_BASE_URL \
                GROK_MODELS_BASE_URL GROK_CODE_XAI_API_KEY
            print "cliproxy: off"
            print "          proxy launchers are disabled"
            print "          direct vendor commands are unchanged"
            ;;
        on)
            command rm -f "${CLIPROXY_OFF_FLAG}"
            export ANTHROPIC_BASE_URL="${CLIPROXY_URL}"
            export ANTHROPIC_AUTH_TOKEN="${CLIPROXY_API_KEY}"
            unset GROK_CLI_CHAT_PROXY_BASE_URL
            print "cliproxy: on (${CLIPROXY_URL})"
            ;;
        status|"")
            if [[ -e "${CLIPROXY_OFF_FLAG}" ]]; then
                print "cliproxy: OFF"
            else
                print "cliproxy: ON  (${CLIPROXY_URL})"
            fi
            print "  claude   ${ANTHROPIC_BASE_URL:-vendor (direct)}"
            if [[ -e "${CLIPROXY_OFF_FLAG}" ]]; then
                print "  grok     vendor (direct)"
            else
                print "  grok     ${CLIPROXY_URL} (sd agent run)"
            fi
            print "  codex    vendor (direct)"
            if [[ -e "${CLIPROXY_OFF_FLAG}" ]]; then
                print "  codex-proxy disabled"
            else
                print "  codex-proxy ${CLIPROXY_URL} (--config override)"
            fi
            if command curl -fsS -o /dev/null --max-time 2 \
                -H "Authorization: Bearer ${CLIPROXY_API_KEY}" \
                "${CLIPROXY_URL}/v1/models" 2>/dev/null; then
                print "  proxy    answering"
            else
                print "  proxy    NOT ANSWERING"
            fi
            ;;
        *)
            print "usage: cliproxy [on|off|status]" >&2
            return 2
            ;;
    esac
}
