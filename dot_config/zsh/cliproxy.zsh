# Route supported CLI harnesses through CLIProxyAPI at 127.0.0.1:8317.
# CPA-Manager-Plus records requests that pass through this endpoint.
#
# Plain `codex` and Codex Desktop connect directly to OpenAI.
# `codex-proxy` selects CLIProxyAPI for one command with `--config`.
# Rune uses `codex-proxy` for all Codex calls.
#
#   cliproxy off      disable proxy launchers
#   cliproxy on       enable proxy launchers
#   cliproxy status   show routes, keys and proxy health
#   noproxy <cmd>     run one command against vendor endpoints
#
# Harnesses use loopback, so they do not depend on Caddy or dnsmasq.
# Claude Code reads ANTHROPIC_BASE_URL from this shell.
# Grok reads GROK_MODELS_BASE_URL and GROK_CODE_XAI_API_KEY from this shell.
# The Codex proxy launcher reads the off flag and overrides model_provider.
#
# The keys come from the owner's secretspec store, the login Keychain
# (runedeck/provision PROV-0028). The `shell` scope holds only the three hub
# client keys, so no other secret, the management key included, reaches a
# shell. A shell reads the store only when it routes and has no key yet: a
# nested shell keeps its parent's keys, and with `cliproxy off` no shell reads
# it. When the keys do not load, the shell stays unrouted and `cliproxy status`
# says why. After a secretspec upgrade, macOS asks once to let the new build
# read the Keychain.

export CLIPROXY_URL="http://127.0.0.1:8317"
CLIPROXY_OFF_FLAG="${HOME}/.config/zsh/cliproxy.off"

# The copy of the manifest that runedeck/provision publishes: it stays put
# whatever change that checkout sits on.
CLIPROXY_SECRETSPEC="${CLIPROXY_SECRETSPEC:-${HOME}/.config/provision/secretspec.toml}"
CLIPROXY_KEYS="${CLIPROXY_API_KEY:+inherited from the parent process}"
CLIPROXY_KEYS="${CLIPROXY_KEYS:-not loaded}"

# Load the three hub client keys from secretspec, as `export NAME='value'`
# lines. Returns non-zero, and puts the reason in CLIPROXY_KEYS, when it
# cannot. secretspec's error text is not shown.
_cliproxy_keys() {
    # A trace (zsh -x) prints each expanded value, so it stays off in every
    # function that handles a key.
    setopt local_options no_xtrace
    local exports line
    [[ -n "${CLIPROXY_API_KEY:-}" ]] && return 0
    if (( ! $+commands[secretspec] )); then
        CLIPROXY_KEYS="not loaded: secretspec is not installed"
        return 1
    fi
    if [[ ! -r "${CLIPROXY_SECRETSPEC}" ]]; then
        CLIPROXY_KEYS="not loaded: no manifest at ${CLIPROXY_SECRETSPEC} (in runedeck/provision: just secrets configure --apply)"
        return 1
    fi
    if ! exports="$(command secretspec export --file "${CLIPROXY_SECRETSPEC}" --profile owner \
        --scope shell --format shell --reason "shell: the hub client keys" 2>/dev/null)"; then
        CLIPROXY_KEYS="not loaded: secretspec export failed (a locked Keychain, or a sandbox that denies it)"
        return 1
    fi
    # Only the three client keys pass, whatever else the scope may list.
    for line in "${(@f)exports}"; do
        [[ "${line}" == "export "(CLIPROXY_API_KEY|CLIPROXY_API_KEY_CODEX|CLIPROXY_API_KEY_GEMINI)=* ]] \
            && eval "${line}"
    done
    if [[ -z "${CLIPROXY_API_KEY:-}" ]]; then
        unset CLIPROXY_API_KEY CLIPROXY_API_KEY_CODEX CLIPROXY_API_KEY_GEMINI
        CLIPROXY_KEYS="not loaded: CLIPROXY_API_KEY is not in the owner store"
        return 1
    fi
    CLIPROXY_KEYS="loaded from secretspec"
}

_cliproxy_route() {
    setopt local_options no_xtrace
    # An unprefixed Claude model selects the highest-priority account.
    # Use `main/<model>` or `rune launch main@claude` for the main account.
    # Fill-first routing changes accounts only after a quota limit.
    # The main account remains available for direct Remote Control sessions.
    export ANTHROPIC_BASE_URL="${CLIPROXY_URL}"
    export ANTHROPIC_AUTH_TOKEN="${CLIPROXY_API_KEY}"
    # Grok's custom-endpoint mode switches it to bearer auth, and the
    # GROK_CODE_ key scopes that bearer to grok so XAI_API_KEY stays free.
    # Grok starts by name (DOT-0007), so the route is set here, not by a launcher.
    export GROK_MODELS_BASE_URL="${CLIPROXY_URL}/v1"
    export GROK_CODE_XAI_API_KEY="${CLIPROXY_API_KEY}"
    unset GROK_CLI_CHAT_PROXY_BASE_URL
}

_cliproxy_unroute() {
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN GROK_CLI_CHAT_PROXY_BASE_URL \
        GROK_MODELS_BASE_URL GROK_CODE_XAI_API_KEY
}

# A shell whose keys did not load drops the hub routes it inherited, so no
# harness keeps a route with a stale token. A route to another endpoint stays.
_cliproxy_drop_hub_routes() {
    if [[ "${ANTHROPIC_BASE_URL:-}" == "${CLIPROXY_URL}" ]]; then
        unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN
    fi
    if [[ "${GROK_MODELS_BASE_URL:-}" == "${CLIPROXY_URL}/v1" ]]; then
        unset GROK_MODELS_BASE_URL GROK_CODE_XAI_API_KEY
    fi
}

# Run one command against the vendor endpoints without changing global state.
# CLIPROXY_BYPASS=1 tells `just -g agent run` to skip its grok proxy injection.
noproxy() {
    env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN \
        -u GROK_MODELS_BASE_URL -u GROK_CODE_XAI_API_KEY \
        CLIPROXY_BYPASS=1 "$@"
}

cliproxy() {
    setopt local_options no_xtrace
    case "${1:-}" in
        off)
            command touch "${CLIPROXY_OFF_FLAG}"
            _cliproxy_unroute
            print "cliproxy: off"
            print "          proxy launchers are disabled"
            print "          direct vendor commands are unchanged"
            ;;
        on)
            command rm -f "${CLIPROXY_OFF_FLAG}"
            if ! _cliproxy_keys; then
                _cliproxy_drop_hub_routes
                print "cliproxy: on, but this shell stays unrouted: keys ${CLIPROXY_KEYS}" >&2
                return 1
            fi
            _cliproxy_route
            print "cliproxy: on (${CLIPROXY_URL})"
            ;;
        status|"")
            if [[ -e "${CLIPROXY_OFF_FLAG}" ]]; then
                print "cliproxy: OFF"
            else
                print "cliproxy: ON  (${CLIPROXY_URL})"
            fi
            print "  keys     ${CLIPROXY_KEYS}"
            print "  claude   ${ANTHROPIC_BASE_URL:-vendor (direct)}"
            if [[ -e "${CLIPROXY_OFF_FLAG}" ]]; then
                print "  grok     vendor (direct)"
            else
                print "  grok     ${GROK_MODELS_BASE_URL:-vendor (direct)}"
            fi
            print "  codex    vendor (direct)"
            if [[ -e "${CLIPROXY_OFF_FLAG}" ]]; then
                print "  codex-proxy disabled"
            else
                print "  codex-proxy ${CLIPROXY_URL} (--config override)"
            fi
            if [[ -z "${CLIPROXY_API_KEY:-}" ]]; then
                print "  proxy    not checked (no key)"
            # curl reads the header from stdin, so the key stays out of its argv.
            elif print -r -- "Authorization: Bearer ${CLIPROXY_API_KEY}" \
                | command curl -fsS -o /dev/null --max-time 2 -H @- \
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

# With the off flag, a shell also drops the hub routes that a parent started
# before `cliproxy off` handed down.
if [[ -e "${CLIPROXY_OFF_FLAG}" ]]; then
    _cliproxy_drop_hub_routes
elif _cliproxy_keys; then
    _cliproxy_route
else
    _cliproxy_drop_hub_routes
fi
