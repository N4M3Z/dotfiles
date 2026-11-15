#!/bin/bash
# The Acrobat lockdown run script must install a valid plist that carries the
# lockdown keys, and must not ask for root when the installed file already
# matches.
#
# The test renders run_after_acrobat-lockdown.sh.tmpl, points it at a
# scratch target through ACROBAT_LOCKDOWN_PLIST, and puts a stub sudo on PATH.
# The stub records each call and copies the offered file to the target, so the
# test can read what a real apply would install.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "skip test-acrobat-lockdown: macOS only"
    exit 0
fi

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/acrobat-lockdown.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

failures=0
fail() {
    echo "FAIL $1"
    [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/    /'
    failures=$((failures + 1))
}

if ! chezmoi execute-template --source "${SOURCE_DIR}" \
        < "${SOURCE_DIR}/run_after_acrobat-lockdown.sh.tmpl" \
        > "${WORKDIR}/run.sh" 2> "${WORKDIR}/render.err"; then
    fail "render" "$(cat "${WORKDIR}/render.err")"
    echo "test-acrobat-lockdown: ${failures} failure(s)"
    exit 1
fi

# Arguments: install -m 644 -o root -g wheel <source> <target>
mkdir -p "${WORKDIR}/bin"
cat > "${WORKDIR}/bin/sudo" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG"
cp "$8" "$9"
STUB
chmod +x "${WORKDIR}/bin/sudo"

target="${WORKDIR}/com.adobe.Reader.plist"
log="${WORKDIR}/sudo.log"
: > "${log}"

run() {
    PATH="${WORKDIR}/bin:${PATH}" STUB_LOG="${log}" ACROBAT_LOCKDOWN_PLIST="${target}" \
        bash "${WORKDIR}/run.sh" 2>&1
}

calls() {
    wc -l < "${log}" | tr -d ' '
}

out=$(run) || fail "first run exited non-zero" "${out}"
[[ "$(calls)" == "1" ]] || fail "first run: expected one sudo call, got $(calls)" "$(cat "${log}")"
grep -q '^install -m 644 -o root -g wheel ' "${log}" \
    || fail "sudo was not asked to install root-owned with mode 644" "$(cat "${log}")"

if [[ -f "${target}" ]]; then
    plutil -lint -s "${target}" || fail "installed plist does not lint"
    check() {
        local value
        value=$(plutil -extract "$1" raw "${target}" 2>&1)
        [[ "${value}" == "$2" ]] || fail "$1: expected $2, got ${value}"
    }
    check DC.FeatureLockdown.bUpdater false
    check DC.FeatureLockdown.cServices.bUpdater false
    check DC.FeatureLockdown.cServices.bToggleNotifications true
    check DC.FeatureLockdown.bAcroSuppressUpsell true
    check DC.FeatureLockdown.bToggleDCAppCenter true
else
    fail "first run installed nothing at the target"
fi

out=$(run) || fail "second run exited non-zero" "${out}"
[[ "$(calls)" == "1" ]] || fail "identical target: expected no new sudo call, got $(calls) total"

printf '<plist version="1.0"><dict/></plist>\n' >| "${target}"
out=$(run) || fail "third run exited non-zero" "${out}"
[[ "$(calls)" == "2" ]] || fail "changed target: expected a second sudo call, got $(calls) total"

if (( failures > 0 )); then
    echo "test-acrobat-lockdown: ${failures} failure(s)"
    exit 1
fi
echo "test-acrobat-lockdown: ok"
