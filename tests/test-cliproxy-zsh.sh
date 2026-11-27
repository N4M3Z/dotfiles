#!/bin/bash
# Regression tests for dot_config/zsh/cliproxy.zsh: how a shell loads the hub
# client keys from secretspec and routes the harnesses. A fake secretspec
# prints synthetic `export` lines, or fails, and logs each call.
# Needs zsh.
# Source: https://github.com/N4M3Z/dotfiles

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SOURCE_FILE="${ROOT}/dot_config/zsh/cliproxy.zsh"
failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
expect() { # <label> <output> <text>...
    local label="$1" out="$2" text
    shift 2
    for text in "$@"; do
        [[ "${out}" == *"${text}"* ]] || { fail "${label} (no '${text}' in: ${out//$'\n'/ | })"; return; }
    done
    pass "${label}"
}
refuse() { # <label> <output> <text>: the text must not appear
    if [[ "$2" == *"$3"* ]]; then fail "$1 ('$3' in: ${2//$'\n'/ | })"; else pass "$1"; fi
}

command -v zsh >/dev/null 2>&1 || { echo "FAIL: these tests need zsh"; exit 1; }
# Each case sets what the shell inherits, so nothing comes from this one.
unset CLIPROXY_API_KEY CLIPROXY_API_KEY_CODEX CLIPROXY_API_KEY_GEMINI ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN \
    GROK_MODELS_BASE_URL GROK_CODE_XAI_API_KEY GROK_CLI_CHAT_PROXY_BASE_URL CLIPROXY_URL CLIPROXY_HOST_FILE
tmp="$(mktemp -d "${TMPDIR:-/tmp}/cliproxy-zsh.XXXXXX")"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/home/.config/zsh" "${tmp}/stub" "${tmp}/bare"
: > "${tmp}/secretspec.toml"
export STUB_LOG="${tmp}/secretspec.log"
cat > "${tmp}/stub/secretspec" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${STUB_LOG}"
case "${STUB_MODE:-ok}" in
    ok) printf "export CLIPROXY_API_KEY='synthetic-claude-key'\nexport CLIPROXY_API_KEY_CODEX='synthetic-codex-key'\n" ;;
    extra) printf "export CLIPROXY_API_KEY='synthetic-claude-key'\nexport CLIPROXY_MGMT_KEY='synthetic-mgmt-key'\n" ;;
    partial) printf "export CLIPROXY_API_KEY_CODEX='synthetic-codex-key'\n" ;;
    empty) ;;
    fail) echo "Error: synthetic-claude-key could not be read" >&2; exit 1 ;;
esac
EOF
# No test reaches a real hub: curl logs its arguments and answers as if
# nothing listens.
export CURL_LOG="${tmp}/curl.log"
cat > "${tmp}/stub/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${CURL_LOG}"
cat >/dev/null
exit 7
EOF
chmod +x "${tmp}/stub/secretspec" "${tmp}/stub/curl"

# shell <PATH> <snippet>: a clean zsh that sources the file, then runs the
# snippet. Environment lines given as KEY=value before the call pass through.
shell() {
    HOME="${tmp}/home" PATH="$1:/usr/bin:/bin" CLIPROXY_SECRETSPEC="${tmp}/secretspec.toml" \
        zsh -f -c 'source "$1"; eval "$2"' _ "${SOURCE_FILE}" "$2" 2>&1
}
routes='print "base=${ANTHROPIC_BASE_URL-} token=${ANTHROPIC_AUTH_TOKEN-} grok=${GROK_MODELS_BASE_URL-} codex=${CLIPROXY_API_KEY_CODEX-}"'

out="$(shell "${tmp}/stub" "${routes}")"
expect 'keys load and the harnesses route through the hub' "${out}" \
    'base=http://127.0.0.1:8317 token=synthetic-claude-key grok=http://127.0.0.1:8317/v1 codex=synthetic-codex-key'
grep -q -- '--scope shell' "${STUB_LOG}" && pass 'the export asks for the shell scope only' || fail 'the export asks for the shell scope only'
grep -q -- '--profile owner' "${STUB_LOG}" && pass 'the export reads the owner profile' || fail 'the export reads the owner profile'
grep -q -- '--reason' "${STUB_LOG}" && pass 'the export gives a reason' || fail 'the export gives a reason'

out="$(shell "${tmp}/stub" 'cliproxy status')"
expect 'cliproxy status checks the hub with the loaded key' "${out}" 'proxy    NOT ANSWERING'
[[ -s "${CURL_LOG}" ]] && pass 'cliproxy status calls curl' || fail 'cliproxy status calls curl'
refuse 'the key is not a curl argument' "$(cat "${CURL_LOG}")" 'synthetic-claude-key'

out="$(HOME="${tmp}/home" PATH="${tmp}/stub:/usr/bin:/bin" CLIPROXY_SECRETSPEC="${tmp}/secretspec.toml" \
    zsh -f -x -c 'source "$1"; cliproxy on; cliproxy status' _ "${SOURCE_FILE}" 2>&1)"
refuse 'a traced shell does not print a key' "${out}" 'synthetic-claude-key'
refuse 'a traced shell does not print the Codex key' "${out}" 'synthetic-codex-key'

out="$(ANTHROPIC_BASE_URL=http://127.0.0.1:8317 ANTHROPIC_AUTH_TOKEN=stale-token \
    GROK_MODELS_BASE_URL=http://127.0.0.1:8317/v1 STUB_MODE=fail shell "${tmp}/stub" "${routes}; cliproxy status")"
expect 'a failed export drops the inherited hub routes' "${out}" 'base= token= grok='
expect 'cliproxy status exists after a failed export and says why' "${out}" 'keys     not loaded: secretspec export failed' 'proxy    not checked (no key)'
refuse 'secretspec error text does not reach the shell' "${out}" 'synthetic-claude-key'

out="$(ANTHROPIC_BASE_URL=https://example.test ANTHROPIC_AUTH_TOKEN=own-token STUB_MODE=fail shell "${tmp}/stub" "${routes}")"
expect 'a failed export keeps a route to another endpoint' "${out}" 'base=https://example.test token=own-token'

out="$(STUB_MODE=extra shell "${tmp}/stub" 'print "mgmt=${CLIPROXY_MGMT_KEY-}"')"
expect 'a name outside the three client keys is not exported' "${out}" 'mgmt='
refuse 'the management key stays out of the shell' "${out}" 'synthetic-mgmt-key'

out="$(STUB_MODE=partial shell "${tmp}/stub" 'print "codex=${CLIPROXY_API_KEY_CODEX-}"; cliproxy status')"
expect 'an export without the main key exports no other key' "${out}" 'codex='
refuse 'a partial export leaves no Codex key behind' "${out}" 'synthetic-codex-key'

out="$(HOME="${tmp}/home" PATH="${tmp}/stub:/usr/bin:/bin" CLIPROXY_SECRETSPEC="${tmp}/secretspec.toml" STUB_MODE=empty \
    zsh -f -u -c 'source "$1"; cliproxy status' _ "${SOURCE_FILE}" 2>&1)"
refuse 'a shell with nounset starts without a parameter error' "${out}" 'parameter not set'

out="$(STUB_MODE=empty shell "${tmp}/stub" 'cliproxy status')"
expect 'an export without the key says the key is missing' "${out}" 'keys     not loaded: CLIPROXY_API_KEY is not in the owner store'

out="$(shell "${tmp}/bare" "${routes}; cliproxy status")"
expect 'without secretspec the shell stays unrouted and status says why' "${out}" 'base= token=' 'keys     not loaded: secretspec is not installed'

: > "${STUB_LOG}"
touch "${tmp}/home/.config/zsh/cliproxy.off"
out="$(shell "${tmp}/stub" "${routes}")"
expect 'with the off flag the shell stays unrouted' "${out}" 'base= token='
[[ ! -s "${STUB_LOG}" ]] && pass 'with the off flag no shell reads the store' || fail 'with the off flag no shell reads the store'
out="$(ANTHROPIC_BASE_URL=http://127.0.0.1:8317 ANTHROPIC_AUTH_TOKEN=stale-token \
    GROK_MODELS_BASE_URL=http://127.0.0.1:8317/v1 CLIPROXY_API_KEY=parent-key shell "${tmp}/stub" "${routes}")"
expect 'with the off flag a shell drops the hub routes it inherited' "${out}" 'base= token= grok='
out="$(STUB_MODE=fail shell "${tmp}/stub" "cliproxy on; print rc=\$?; ${routes}")"
expect 'cliproxy on with keys that do not load fails and stays unrouted' "${out}" 'stays unrouted: keys not loaded' 'rc=1' 'base= token='
out="$(shell "${tmp}/stub" "cliproxy on; ${routes}")"
expect 'cliproxy on loads the keys and routes' "${out}" 'cliproxy: on' 'base=http://127.0.0.1:8317 token=synthetic-claude-key'
rm -f "${tmp}/home/.config/zsh/cliproxy.off"

mkdir -p "${tmp}/home/.config/provision"
cp "${tmp}/secretspec.toml" "${tmp}/home/.config/provision/secretspec.toml"
out="$(HOME="${tmp}/home" PATH="${tmp}/stub:/usr/bin:/bin" zsh -f -c 'source "$1"; eval "$2"' _ "${SOURCE_FILE}" "${routes}" 2>&1)"
expect 'without an override the manifest is the one runedeck/provision publishes' "${out}" 'token=synthetic-claude-key'
grep -q -- "--file ${tmp}/home/.config/provision/secretspec.toml" "${STUB_LOG}" \
    && pass 'the export reads ~/.config/provision/secretspec.toml' || fail 'the export reads ~/.config/provision/secretspec.toml'

: > "${STUB_LOG}"
out="$(CLIPROXY_API_KEY=parent-key shell "${tmp}/stub" "${routes}; cliproxy status")"
expect 'a nested shell routes with the keys it inherited' "${out}" 'token=parent-key' 'keys     inherited from the parent process'
[[ ! -s "${STUB_LOG}" ]] && pass 'a nested shell does not read the store again' || fail 'a nested shell does not read the store again'

# The hub from ~/.config/zsh/cliproxy.host, which chezmoi renders from proxy_host.
printf 'cliproxy.example.test\n' > "${tmp}/home/.config/zsh/cliproxy.host"
out="$(shell "${tmp}/stub" "${routes}; cliproxy status")"
expect 'the host file routes to the hub over HTTPS' "${out}" \
    'base=https://cliproxy.example.test token=synthetic-claude-key grok=https://cliproxy.example.test/v1' \
    'cliproxy: ON  (https://cliproxy.example.test)'
out="$(CLIPROXY_URL=http://127.0.0.1:9999 shell "${tmp}/stub" "${routes}")"
expect 'an inherited CLIPROXY_URL wins over the host file' "${out}" 'base=http://127.0.0.1:9999'
printf 'https://evil.example/x\n' > "${tmp}/home/.config/zsh/cliproxy.host"
out="$(shell "${tmp}/stub" "${routes}")"
expect 'a host file with more than a host name keeps the loopback route' "${out}" 'base=http://127.0.0.1:8317'
rm -f "${tmp}/home/.config/zsh/cliproxy.host"

if [[ ${failures} -gt 0 ]]; then
    echo "${failures} test(s) failed"
    exit 1
fi
echo "All cliproxy.zsh tests passed"
