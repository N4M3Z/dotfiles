#!/bin/bash
# Render the templates against the private values both ways. Stub pass and
# pass-cli commands on PATH answer only the dotfiles/proton entry, with a
# fixture NAME=value line for each key of .chezmoidata/private.yaml. A stub
# secretspec command answers one name at a time from the same fixture.
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
cat > "${WORKDIR}/bin/secretspec" <<'STUB'
#!/bin/sh
# `secretspec --file <manifest> --reason <text> get NAME` prints the fixture
# value of NAME with no newline, and fails for a name the fixture lacks.
[ "$#" -eq 6 ] && [ "$1" = --file ] && [ -f "$2" ] && [ "$3" = --reason ] && [ "$5" = get ] || exit 2
grep -q "^$6=" "$FIXTURE_BODY" || exit 1
sed -n "s/^$6=//p" "$FIXTURE_BODY" | tr -d '\n'
STUB
chmod +x "${WORKDIR}/bin/pass" "${WORKDIR}/bin/pass-cli" "${WORKDIR}/bin/secretspec"

# The secretspec store reads a value by the name that secretspec.toml declares.
declared=$(yq -p=toml -o=json '.profiles.default | keys' "${SOURCE_DIR}/secretspec.toml" | jq -r '.[]') \
    || { echo "FAIL read: secretspec.toml"; exit 1; }
while IFS= read -r name; do
    grep -qxF -- "${name}" <<< "${declared}" || fail "secretspec.toml does not declare ${name}"
done < <(jq -r 'keys[] | ascii_upcase' <<< "${placeholder_map}")

for store in pass proton-pass secretspec; do
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

# A config from an earlier init lacks a value that was added later. The guard
# script must stop that apply, and must render nothing in the two good states.
guard="${SOURCE_DIR}/run_before_check_private_values.sh.tmpl"
printf '[data]\n    privateStore = "pass"\n' > "${WORKDIR}/stale.toml"
if ! render "${WORKDIR}/stale.toml" < "${guard}" | grep -qx 'exit 1'; then
    fail "the guard does not stop an apply with a stale config"
fi
for config in pass empty; do
    if [[ -n "$(render "${WORKDIR}/${config}.toml" < "${guard}")" ]]; then
        fail "the guard renders a script with the ${config} config"
    fi
done
if [[ ${failures} -gt 0 ]]; then
    echo "test-private-data: ${failures} failure(s)"
    exit 1
fi
echo "test-private-data: every template resolves the private values with the config and keeps the placeholders without it"
