#!/bin/bash
# The SSH config must load the private host files for every host, must let a
# host block win over a default, and must not forward the agent by default.
# `ssh -G` prints the options OpenSSH would use for a host and connects to
# nothing. The Include lines point at fixture files in a temporary folder.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/ssh-config.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

mkdir "${WORKDIR}/vendor"
cat > "${WORKDIR}/hosts" <<'FIXTURE'
Host fixture-jump
    Port 2222
    ForwardAgent yes
FIXTURE
sed -e "s|^Include hosts\$|Include ${WORKDIR}/hosts|" \
    -e "s|^Include vendor/\\*\$|Include ${WORKDIR}/vendor/*|" \
    "${SOURCE_DIR}/private_dot_ssh/private_config" > "${WORKDIR}/config"
if ! grep -q "^Include ${WORKDIR}/hosts\$" "${WORKDIR}/config"; then
    echo "FAIL the config has no 'Include hosts' line to point at the fixture"
    exit 1
fi

failures=0
option() {
    ssh -G -F "${WORKDIR}/config" "$1" 2> "${WORKDIR}/err" | sed -n "s/^$2 //p"
}
expect() {
    local host=$1 name=$2 want=$3 got
    got=$(option "${host}" "${name}")
    if [[ "${got}" == "${want}" ]]; then
        echo "ok ${host}: ${name} ${want}"
    else
        echo "FAIL ${host}: ${name} is '${got}', expected '${want}'"
        cat "${WORKDIR}/err"
        failures=$((failures + 1))
    fi
}

# A host from the private file: its block loads, and it wins over the defaults.
expect fixture-jump port 2222
expect fixture-jump forwardagent yes
# Any other host: the defaults apply, and the agent stays on this machine.
expect fixture-other port 22
expect fixture-other forwardagent no
expect fixture-other serveraliveinterval 60
# github.com keeps its key settings.
expect github.com identitiesonly yes
expect github.com forwardagent no

if [[ ${failures} -gt 0 ]]; then
    echo "test-ssh-config: ${failures} failure(s)"
    exit 1
fi
echo "test-ssh-config: host blocks load for every host and win over the defaults"
