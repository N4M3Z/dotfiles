#!/bin/bash
# Muse Code must start without the Claude OTEL endpoint, and Claude must keep
# it.
#
# otel.zsh exports OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 for
# Claude Code from every zsh. Muse 1.4.20 withholds its Model API bearer
# from a non-baseline destination, disables telemetry export, and prints a
# notice at every interactive start. A PTY probe on Nexus.local showed that
# unsetting the endpoint for the muse process removes the notice and that
# OTEL_SDK_DISABLED=true does not. So otel.zsh defines a muse() wrapper that
# unsets its OTEL list for that one process. This test sources otel.zsh in
# bash (the file uses no zsh-only syntax) with a stub muse on PATH that
# prints the OTEL variables it received.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/muse-telemetry.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

mkdir -p "${WORKDIR}/bin"
cat > "${WORKDIR}/bin/muse" <<'STUB'
#!/bin/sh
env | grep '^OTEL_' | sort
echo "args:$*"
STUB
chmod +x "${WORKDIR}/bin/muse"

failures=0
fail() {
    echo "FAIL $1"
    [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/    /'
    failures=$((failures + 1))
}

out=$(PATH="${WORKDIR}/bin:${PATH}" bash -c '
    source "$1"
    echo "shell-endpoint:${OTEL_EXPORTER_OTLP_ENDPOINT:-UNSET}"
    echo "shell-exporter:${OTEL_TRACES_EXPORTER:-UNSET}"
    muse probe-arg
' _ "${SOURCE_DIR}/dot_config/zsh/otel.zsh" 2>&1) || {
    fail "sourcing otel.zsh and running muse failed:" "${out}"
    echo "test-muse-telemetry: ${failures} failure(s)"
    exit 1
}

shell_endpoint=$(printf '%s\n' "${out}" | sed -n 's/^shell-endpoint://p')
if [[ "${shell_endpoint}" == "http://localhost:4318" ]]; then
    echo "ok the shell keeps the Claude OTEL endpoint"
else
    fail "the shell lost the Claude OTEL endpoint (got: ${shell_endpoint:-none})"
fi

child_otel=$(printf '%s\n' "${out}" | grep '^OTEL_' || true)
if [[ -z "${child_otel}" ]]; then
    echo "ok the muse process receives no OTEL variables"
else
    fail "the muse process still receives OTEL variables:" "${child_otel}"
fi

if printf '%s\n' "${out}" | grep -qx 'args:probe-arg'; then
    echo "ok the wrapper passes its arguments to the muse binary"
else
    fail "the wrapper does not pass arguments through:" "${out}"
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-muse-telemetry: ${failures} failure(s)"
    exit 1
fi
echo "test-muse-telemetry: muse starts clean and Claude keeps its collector"
