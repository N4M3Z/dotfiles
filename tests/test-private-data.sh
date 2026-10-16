#!/bin/bash
# Render the templates against the private values both ways. Stub pass and
# pass-cli commands on PATH answer only the dotfiles/proton entry, with a
# fixture NAME=value line for each key of .chezmoidata/private.yaml.
# .chezmoi.toml.tmpl renders once for each store into a temporary config, which
# must set every key. With the config no template may keep a placeholder, and
# every template that reads .private must carry a fixture value. Without a
# config (CI, a machine before chezmoi init), those templates must carry the
# placeholders instead. The real stores are never read.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-private.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

# run_onchange_after_brew.sh.tmpl hashes the provisioning Brewfile at render
# time; only the path needs to exist for rendering, not real content.
BREWFILE_DIR="${HOME}/Developer/N4M3Z/forge-provision/manifests"
mkdir -p "${BREWFILE_DIR}"
[[ -f "${BREWFILE_DIR}/Brewfile" ]] || touch "${BREWFILE_DIR}/Brewfile"

failures=0
fail() {
    echo "FAIL $*"
    failures=$((failures + 1))
}

render() {
    chezmoi --config "$1" execute-template --source "${SOURCE_DIR}"
}

# An empty config has no private data, whatever the developer's own config holds.
: > "${WORKDIR}/empty.toml"

placeholder_map=$(printf '%s' '{{ .private | toJson }}' | render "${WORKDIR}/empty.toml") \
    || { echo "FAIL render: private placeholders"; exit 1; }
placeholders=$(jq -r '.[]' <<< "${placeholder_map}")

export FIXTURE_BODY="${WORKDIR}/body.yaml"
jq -r 'to_entries[] | "\(.key | ascii_upcase)=fixture-\(.key | gsub("_"; "-")).example.test"' \
    <<< "${placeholder_map}" > "${FIXTURE_BODY}"

mkdir "${WORKDIR}/bin"
cat > "${WORKDIR}/bin/pass" <<'STUB'
#!/bin/sh
# `pass show dotfiles/proton` prints the fixture body.
[ "$#" -eq 2 ] && [ "$1" = show ] && [ "$2" = dotfiles/proton ] || exit 2
cat "$FIXTURE_BODY"
STUB
cat > "${WORKDIR}/bin/pass-cli" <<'STUB'
#!/bin/sh
# `pass-cli item view pass://dotfiles/proton/note` prints the fixture body.
[ "$#" -eq 3 ] && [ "$1" = item ] && [ "$2" = view ] && [ "$3" = pass://dotfiles/proton/note ] || exit 2
cat "$FIXTURE_BODY"
STUB
chmod +x "${WORKDIR}/bin/pass" "${WORKDIR}/bin/pass-cli"

for store in pass proton-pass; do
    PATH="${WORKDIR}/bin:${PATH}" chezmoi --config "${WORKDIR}/empty.toml" execute-template --init \
        --promptChoice "Store for private values=${store}" --source "${SOURCE_DIR}" \
        < "${SOURCE_DIR}/.chezmoi.toml.tmpl" > "${WORKDIR}/${store}.toml" \
        || { echo "FAIL render: .chezmoi.toml.tmpl with ${store}"; exit 1; }
    store_map=$(printf '%s' '{{ .private | toJson }}' | render "${WORKDIR}/${store}.toml") \
        || { echo "FAIL render: private values from ${store}"; exit 1; }
    while IFS= read -r key; do
        [[ -n "${key}" ]] && fail ".chezmoi.toml.tmpl does not set private.${key} from ${store}"
    done < <(jq -rn --argjson p "${placeholder_map}" --argjson f "${store_map}" \
        '$p | keys[] | select($p[.] == $f[.])')
done
fixtures=$(printf '%s' '{{ .private | toJson }}' | render "${WORKDIR}/pass.toml" | jq -r '.[]')

contains_any() {
    local file=$1 values=$2 value
    while IFS= read -r value; do
        grep -qF -- "${value}" "${file}" && return 0
    done <<< "${values}"
    return 1
}

index=0
consumers=0
while IFS= read -r template; do
    index=$((index + 1))
    relative="${template#"${SOURCE_DIR}"/}"
    with_config="${WORKDIR}/with-config-${index}"
    without_config="${WORKDIR}/without-config-${index}"

    if ! render "${WORKDIR}/pass.toml" < "${template}" > "${with_config}" 2>&1; then
        fail "render with config: ${relative}"
        continue
    fi
    if contains_any "${with_config}" "${placeholders}"; then
        fail "placeholder left with config: ${relative}"
    fi

    grep -qF '.private.' "${template}" || continue

    if ! contains_any "${with_config}" "${fixtures}"; then
        fail "no private value with config: ${relative}"
    fi
    if ! render "${WORKDIR}/empty.toml" < "${template}" > "${without_config}" 2>&1; then
        fail "render without config: ${relative}"
        continue
    fi
    if ! contains_any "${without_config}" "${placeholders}"; then
        fail "no placeholder without config: ${relative}"
    fi
    consumers=$((consumers + 1))
    echo "ok private: ${relative}"
done < <(find "${SOURCE_DIR}" -name '*.tmpl' -not -name '.chezmoi.toml.tmpl' \
    -not -path "${SOURCE_DIR}/.git/*" -not -path "${SOURCE_DIR}/.jj/*" \
    -not -path "${SOURCE_DIR}/.workspaces/*" | sort)

if [[ ${consumers} -eq 0 ]]; then
    fail "no template reads .private"
fi
if [[ ${failures} -gt 0 ]]; then
    echo "test-private-data: ${failures} failure(s)"
    exit 1
fi
echo "test-private-data: every template resolves the private values with the config and keeps the placeholders without it"
