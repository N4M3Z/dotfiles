# Route the coding harnesses through the local CLIProxyAPI (127.0.0.1:8317) so
# CPA-Manager-Plus meters their spend.
#
#   cliproxy off      unwire everything, now
#   cliproxy on       wire it back
#   cliproxy status   what is wired, and is the proxy answering
#   noproxy <cmd>     run one command against vendor endpoints
#
# Loopback, not https://cliproxy.internal: harnesses must not depend on Caddy or
# dnsmasq being healthy. The nice names are for browsing.
#
# Three wiring mechanisms, because the harnesses differ:
#   env      Claude Code (ANTHROPIC_BASE_URL) — unset and it is free
#   launcher grok — `sd agent run grok` exports GROK_MODELS_BASE_URL and a
#            Grok-scoped bearer into its child only. It honors the off flag
#            and the CLIPROXY_BYPASS=1 marker `noproxy` sets, so no ambient
#            grok variables exist to go stale.
#   config   Codex — its model_provider lives in ~/.codex/config.toml and has no
#            environment override, so `cliproxy off` comments that line out. It
#            is marked with CLIPROXY-TOGGLE so the edit is exact. This matters:
#            `rune run codex` and HarnessCouncil invoke the binary directly and
#            never see shell state, so env alone would leave them on a dead proxy.
#
# Only the CLIPROXY_* values are read out of ~/.env — sourcing the whole file
# would export every unrelated secret into every shell.

export CLIPROXY_URL="http://127.0.0.1:8317"
CLIPROXY_OFF_FLAG="${HOME}/.config/zsh/cliproxy.off"
CLIPROXY_CODEX_CONFIG="${HOME}/.codex/config.toml"

[[ -r "${HOME}/.env" ]] || return 0

# Keys load either way: `cliproxy status`, CPA-Manager-Plus, and the rune launch
# profiles all need them even while global wiring is off.
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
    # Claude Code. An unprefixed model id resolves to the top-priority account
    # (the pm.me subscription, prefix alt/); `main/<model>` and `rune launch
    # main@claude` explicitly target claude@martinzeman.net. Fill-first
    # routing serves one account until its quota is exhausted, then spills to
    # the next for as long as the cooldown lasts, so an unprefixed request
    # never blends accounts mid-session but also never dead-ends on a limit
    # while a second subscription sits idle. claude@martinzeman.net sits at
    # spillover priority because it also serves direct Remote Control
    # sessions outside the proxy; `noproxy claude` starts one.
    export ANTHROPIC_BASE_URL="${CLIPROXY_URL}"
    export ANTHROPIC_AUTH_TOKEN="${CLIPROXY_API_KEY}"
fi

# Run one command against the vendor endpoints without changing global state.
# CLIPROXY_BYPASS=1 tells `sd agent run` to skip its grok proxy injection.
# Codex needs its own escape: --profile direct restores the vendor provider.
noproxy() {
    if [[ "$1" == "codex" ]]; then
        shift
        env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN \
            CLIPROXY_BYPASS=1 codex --profile direct "$@"
    else
        env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN \
            CLIPROXY_BYPASS=1 "$@"
    fi
}

cliproxy() {
    case "$1" in
        off)
            command touch "${CLIPROXY_OFF_FLAG}"
            command sed -i '' 's|^model_provider = "cliproxyapi"  # CLIPROXY-TOGGLE|# model_provider = "cliproxyapi"  # CLIPROXY-TOGGLE|' "${CLIPROXY_CODEX_CONFIG}" 2>/dev/null
            unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN GROK_CLI_CHAT_PROXY_BASE_URL \
                GROK_MODELS_BASE_URL GROK_CODE_XAI_API_KEY
            print "cliproxy: off (codex on vendor provider; this shell unwired)"
            print "          new shells inherit it; spend is no longer metered"
            ;;
        on)
            command rm -f "${CLIPROXY_OFF_FLAG}"
            command sed -i '' 's|^# model_provider = "cliproxyapi"  # CLIPROXY-TOGGLE|model_provider = "cliproxyapi"  # CLIPROXY-TOGGLE|' "${CLIPROXY_CODEX_CONFIG}" 2>/dev/null
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
            if command grep -q '^model_provider = "cliproxyapi"  # CLIPROXY-TOGGLE' "${CLIPROXY_CODEX_CONFIG}" 2>/dev/null; then
                print "  codex    ${CLIPROXY_URL} (config.toml)"
            else
                print "  codex    vendor (direct)"
            fi
            if command curl -fsS -o /dev/null --max-time 2 \
                -H "Authorization: Bearer ${CLIPROXY_API_KEY}" \
                "${CLIPROXY_URL}/v1/models" 2>/dev/null; then
                print "  proxy    answering"
            else
                print "  proxy    NOT ANSWERING — run \`cliproxy off\` to fall back"
            fi
            ;;
        *)
            print "usage: cliproxy [on|off|status]" >&2
            return 2
            ;;
    esac
}
