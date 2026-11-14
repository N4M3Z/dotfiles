#!/bin/bash
# Regression tests for dot_config/zsh/browserbase.zsh: how a shell loads the
# Browserbase key from secretspec. A fake secretspec prints a synthetic value,
# or fails, and logs each call. Needs zsh.
# Source: https://github.com/N4M3Z/dotfiles

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SOURCE_FILE="${ROOT}/dot_config/zsh/browserbase.zsh"
failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
expect() { # <label> <output> <text>
    if [[ "$2" == *"$3"* ]]; then pass "$1"; else fail "$1 (no '$3' in: ${2//$'\n'/ | })"; fi
}
refuse() { # <label> <output> <text>: the text must not appear
    if [[ "$2" == *"$3"* ]]; then fail "$1 ('$3' in: ${2//$'\n'/ | })"; else pass "$1"; fi
}

command -v zsh >/dev/null 2>&1 || { echo "FAIL: these tests need zsh"; exit 1; }
unset BROWSERBASE_API_KEY BROWSERBASE_SECRETSPEC
tmp="$(mktemp -d "${TMPDIR:-/tmp}/browserbase-zsh.XXXXXX")"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/home/.config/provision" "${tmp}/stub" "${tmp}/bare"
: > "${tmp}/secretspec.toml"
export STUB_LOG="${tmp}/secretspec.log"
cat > "${tmp}/stub/secretspec" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${STUB_LOG}"
case "${STUB_MODE:-ok}" in
    ok) printf 'synthetic-browserbase-key\n' ;;
    fail) echo "Error: synthetic-browserbase-key could not be read" >&2; exit 1 ;;
esac
EOF
chmod +x "${tmp}/stub/secretspec"

# shell <PATH> <manifest> [zsh flags]: a clean interactive zsh that sources the
# file and prints the key in brackets, so an empty key reads `key=[]`.
shell() {
    HOME="${tmp}/home" PATH="$1:/usr/bin:/bin" BROWSERBASE_SECRETSPEC="$2" \
        zsh -f -i ${3:-} -c 'source "$1"; print "key=[${BROWSERBASE_API_KEY-}]"' _ "${SOURCE_FILE}" 2>&1
}

out="$(shell "${tmp}/stub" "${tmp}/secretspec.toml")"
expect 'the key loads from secretspec' "${out}" 'key=[synthetic-browserbase-key]'
grep -q -- "get BROWSERBASE_API_KEY --file ${tmp}/secretspec.toml --profile owner" "${STUB_LOG}" \
    && pass 'the read names the key, the manifest and the owner profile' \
    || fail 'the read names the key, the manifest and the owner profile'
grep -q -- '--reason' "${STUB_LOG}" && pass 'the read gives a reason' || fail 'the read gives a reason'

out="$(shell "${tmp}/stub" "${tmp}/secretspec.toml" -x)"
expect 'a traced shell still loads the key' "${out}" 'key=[synthetic-browserbase-key]'
refuse 'a traced shell does not trace the key' "${out//key=\[synthetic-browserbase-key\]/}" 'synthetic-browserbase-key'

: > "${STUB_LOG}"
out="$(HOME="${tmp}/home" PATH="${tmp}/stub:/usr/bin:/bin" BROWSERBASE_SECRETSPEC="${tmp}/secretspec.toml" \
    zsh -f -c 'source "$1"; print "key=[${BROWSERBASE_API_KEY-}]"' _ "${SOURCE_FILE}" 2>&1)"
expect 'a non-interactive shell leaves the key unset' "${out}" 'key=[]'
[[ ! -s "${STUB_LOG}" ]] && pass 'a non-interactive shell does not read the store' || fail 'a non-interactive shell does not read the store'

out="$(STUB_MODE=fail shell "${tmp}/stub" "${tmp}/secretspec.toml")"
expect 'a failed read leaves the key unset' "${out}" 'key=[]'
refuse 'secretspec error text does not reach the shell' "${out}" 'synthetic-browserbase-key'

: > "${STUB_LOG}"
out="$(shell "${tmp}/stub" "${tmp}/missing.toml")"
expect 'without the manifest the key stays unset' "${out}" 'key=[]'
[[ ! -s "${STUB_LOG}" ]] && pass 'without the manifest no shell reads the store' || fail 'without the manifest no shell reads the store'

out="$(shell "${tmp}/bare" "${tmp}/secretspec.toml")"
expect 'without secretspec the key stays unset' "${out}" 'key=[]'

: > "${STUB_LOG}"
out="$(BROWSERBASE_API_KEY=parent-key shell "${tmp}/stub" "${tmp}/secretspec.toml")"
expect 'a nested shell keeps the key it inherited' "${out}" 'key=[parent-key]'
[[ ! -s "${STUB_LOG}" ]] && pass 'a nested shell does not read the store again' || fail 'a nested shell does not read the store again'

: > "${STUB_LOG}"
cp "${tmp}/secretspec.toml" "${tmp}/home/.config/provision/secretspec.toml"
out="$(HOME="${tmp}/home" PATH="${tmp}/stub:/usr/bin:/bin" \
    zsh -f -i -c 'source "$1"; print "key=[${BROWSERBASE_API_KEY-}]"' _ "${SOURCE_FILE}" 2>&1)"
expect 'without an override the key loads' "${out}" 'key=[synthetic-browserbase-key]'
grep -q -- "--file ${tmp}/home/.config/provision/secretspec.toml" "${STUB_LOG}" \
    && pass 'the read uses ~/.config/provision/secretspec.toml' || fail 'the read uses ~/.config/provision/secretspec.toml'

if [[ ${failures} -gt 0 ]]; then
    echo "${failures} test(s) failed"
    exit 1
fi
echo "All browserbase.zsh tests passed"
