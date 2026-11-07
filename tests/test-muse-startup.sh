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
    for target in "${WORKDIR}/verify.sh" "${SOURCE_DIR}/tests/test-muse-sandbox.sh"; do
        observed=0
        result=$(PATH="${WORKDIR}/bin:${PATH}" MUSE_TEST_OUTPUT="${output}" MUSE_TEST_EXIT="${code}" \
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

if [[ ${failures} -gt 0 ]]; then
    echo "test-muse-startup: ${failures} failure(s)"
    exit 1
fi
echo "test-muse-startup: both probes retain unrelated startup failures"
