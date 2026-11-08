#!/bin/bash
# A hidden socket may skip its own startup probe. It must not hide another
# diagnostic or an unrelated exit code in either verification path.
set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/muse-startup.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT
mkdir -p "${WORKDIR}/bin"

chezmoi execute-template --source "${SOURCE_DIR}" \
    < "${SOURCE_DIR}/run_after_verify_harness_config.sh.tmpl" > "${WORKDIR}/verify.sh" || exit 1

cat > "${WORKDIR}/bin/muse" <<'STUB'
#!/bin/sh
printf '%s\n' "$MUSE_TEST_OUTPUT"
exit "$MUSE_TEST_EXIT"
STUB
for tool in codex claude grok; do
    printf '#!/bin/sh\nprintf "{}\\n"\n' > "${WORKDIR}/bin/${tool}"
done
chmod +x "${WORKDIR}/bin/"*

failures=0
check() {
    local name=$1 code=$2 output=$3 want=$4 target result observed
    local tool_path=${5:-${WORKDIR}/bin:${PATH}}
    for target in "${WORKDIR}/verify.sh" "${SOURCE_DIR}/tests/test-muse-sandbox.sh"; do
        observed=0
        result=$(PATH="${tool_path}" MUSE_TEST_OUTPUT="${output}" MUSE_TEST_EXIT="${code}" \
            bash "${target}" 2>&1) || observed=$?
        if [[ ( ${want} == pass && ${observed} -eq 0 ) || ( ${want} == fail && ${observed} -ne 0 ) ]]; then
            echo "ok ${name}: $(basename "${target}") ${want}"
        else
            echo "FAIL ${name}: $(basename "${target}") exit ${observed}, want ${want}"
            printf '%s\n' "${result}"
            failures=$((failures + 1))
        fi
    done
}

socket_problem="Named permission profiles are unavailable: unresolvable Unix socket path \`${WORKDIR}/missing/S.gpg-agent\`."
check healthy 0 'probe' pass
check hidden-socket-only 1 "${socket_problem}" pass
check socket-and-unknown-key 1 "${socket_problem}"$'\nunknown key `broken`' fail
check socket-and-other-error 1 "${socket_problem}"$'\nunexpected startup failure' fail
check socket-with-other-exit 7 "${socket_problem}" fail
check unknown-key-with-zero-exit 0 "unknown key \`broken\`" fail
check empty-failure 1 '' fail
check readable-socket-folder 1 "Named permission profiles are unavailable: unresolvable Unix socket path \`${WORKDIR}/S.gpg-agent\`." fail

# Use a PATH that contains only the tools these probes need. Each fixture
# controls whether timeout, gtimeout, or neither command is installed.
cat > "${WORKDIR}/timeout-wrapper" <<'STUB'
#!/bin/sh
printf '%s\n' "${0##*/}" >> "$MUSE_TEST_TIMEOUT_LOG"
[ "$1" = 120 ] || exit 99
shift
exec "$@"
STUB
chmod +x "${WORKDIR}/timeout-wrapper"
for mode in none gtimeout timeout; do
    tool_path="${WORKDIR}/path-${mode}"
    mkdir -p "${tool_path}"
    for tool in bash cat chezmoi cp dirname grep jq mkdir mktemp rm sed tail; do
        tool_binary=$(command -v "${tool}") || exit 1
        ln -s "${tool_binary}" "${tool_path}/${tool}" || exit 1
    done
    ln -s "${WORKDIR}/bin/muse" "${tool_path}/muse" || exit 1
    expected=""
    if [[ ${mode} != none ]]; then
        ln -s "${WORKDIR}/timeout-wrapper" "${tool_path}/gtimeout" || exit 1
        expected=gtimeout
    fi
    if [[ ${mode} == timeout ]]; then
        ln -s "${WORKDIR}/timeout-wrapper" "${tool_path}/timeout" || exit 1
        expected=timeout
    fi
    export MUSE_TEST_TIMEOUT_LOG="${WORKDIR}/timeout-${mode}.log"
    : > "${MUSE_TEST_TIMEOUT_LOG}"
    check "healthy-timeout-${mode}" 0 probe pass "${tool_path}"
    observed=$(cat "${MUSE_TEST_TIMEOUT_LOG}")
    if [[ ${observed} != "${expected}" ]]; then
        echo "FAIL timeout-${mode}: used '${observed}', want '${expected}'"
        failures=$((failures + 1))
    fi
    if [[ ${mode} == none ]]; then
        check unknown-key-without-timeout 0 "unknown key \`broken\`" fail "${tool_path}"
    fi
done

if [[ ${failures} -gt 0 ]]; then
    echo "test-muse-startup: ${failures} failure(s)"
    exit 1
fi
echo "test-muse-startup: both probes retain unrelated startup failures"
