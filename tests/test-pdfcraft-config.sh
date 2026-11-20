#!/bin/bash
# The PdfCraft modify template must turn the update check at start off and
# keep every other byte of app.ron.
#
# The test applies the template with chezmoi to a scratch destination and
# compares the result with the expected file byte for byte.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SOURCE_FILE="Library/Application Support/PdfCraft/modify_app.ron"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/pdfcraft-config.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

mkdir -p "${WORKDIR}/source/${SOURCE_FILE%/*}" "${WORKDIR}/dest/${SOURCE_FILE%/*}"
cp "${SOURCE_DIR}/${SOURCE_FILE}" "${WORKDIR}/source/${SOURCE_FILE}"
: > "${WORKDIR}/chezmoi.toml"
target="${WORKDIR}/dest/Library/Application Support/PdfCraft/app.ron"

failures=0
fail() {
    echo "FAIL $1"
    [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/    /'
    failures=$((failures + 1))
}

apply() {
    chezmoi apply --source "${WORKDIR}/source" --destination "${WORKDIR}/dest" \
        --config "${WORKDIR}/chezmoi.toml" --persistent-state "${WORKDIR}/state.boltdb" \
        --cache "${WORKDIR}/cache" --no-tty --force "${target}" 2>&1
}

# Written the way PdfCraft 0.21 writes it: RON escapes such as \u{301} and \'
# must come through unchanged.
cat > "${WORKDIR}/live.ron" <<'EOF'
{
    "pdfcraft": "{\"recent\":[{\"name\":\"pla\u{301}n\'s.pdf\"}],\"trusted\":[\"-----BEGIN CERTIFICATE-----\\nAAAA\\n\"],\"update_check_at_start\":true,\"zoom\":87.5}",
    "egui": "(options:(theme_preference:System,zoom_factor:1.0),data:([]))",
    "window": "(fullscreen:false,maximized:false)",
}
EOF
sed 's/update_check_at_start\\":true/update_check_at_start\\":false/' "${WORKDIR}/live.ron" > "${WORKDIR}/want.ron"
printf '{\n    "pdfcraft": "{\\"update_check_at_start\\":false}",\n}\n' > "${WORKDIR}/fresh.ron"

cp "${WORKDIR}/live.ron" "${target}"
out=$(apply) || fail "apply on a live file exited non-zero" "${out}"
cmp -s "${target}" "${WORKDIR}/want.ron" || fail "only the update check may change" "$(diff "${WORKDIR}/want.ron" "${target}")"

out=$(apply) || fail "second apply exited non-zero" "${out}"
cmp -s "${target}" "${WORKDIR}/want.ron" || fail "second apply changed the file"

command rm -f "${target}"
out=$(apply) || fail "apply without a file exited non-zero" "${out}"
cmp -s "${target}" "${WORKDIR}/fresh.ron" || fail "a new file must hold only the managed pref" "$(cat "${target}")"

printf '{\n    "pdfcraft": "{\\"zoom\\":87.5}",\n}\n' > "${target}"
cp "${target}" "${WORKDIR}/nokey.ron"
if out=$(apply); then
    fail "apply must refuse a file without the pref"
fi
cmp -s "${target}" "${WORKDIR}/nokey.ron" || fail "a refused apply changed the file"

if (( failures > 0 )); then
    echo "test-pdfcraft-config: ${failures} failure(s)"
    exit 1
fi
echo "test-pdfcraft-config: ok"
