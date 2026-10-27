#!/bin/bash
# Every top-level target this repository deploys into the home folder must be a
# dot entry or a known home folder. A source entry without a dot_ prefix deploys
# visibly into $HOME: that is how ~/sd, ~/defaults.yaml, and ~/module.yaml
# appeared. Ignore repository files in .chezmoiignore, or give the source a
# dot_ name.
# Source: https://github.com/N4M3Z/dotfiles

set -o pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-home-targets.XXXXXX") || exit 1
trap 'command rm -rf "$WORKDIR"' EXIT

# run_onchange_after_brew.sh.tmpl hashes the provisioning Brewfile at render
# time; only the path needs to exist for rendering, not real content.
BREWFILE_DIR="${HOME}/Developer/N4M3Z/forge-provision/manifests"
mkdir -p "${BREWFILE_DIR}"
[[ -f "${BREWFILE_DIR}/Brewfile" ]] || touch "${BREWFILE_DIR}/Brewfile"
[[ -f "${BREWFILE_DIR}/Brewfile.work" ]] || touch "${BREWFILE_DIR}/Brewfile.work"

# Visible home folders a source may deploy into. Keep in step with
# forge-provision scripts/verify/home-hygiene.sh.
allowed=(Agents Applications Atlas Data Desktop Developer Documents Downloads
    Games Library Movies Music Pictures Public)

: > "${WORKDIR}/empty.toml"

targets=$(chezmoi --config "${WORKDIR}/empty.toml" --source "${SOURCE_DIR}" \
    managed --include files,dirs,symlinks --path-style relative) \
    || { echo "FAIL chezmoi managed"; exit 1; }

failures=0
while IFS= read -r top; do
    [[ -z "${top}" || "${top}" == .* ]] && continue
    known=0
    for name in "${allowed[@]}"; do
        [[ "${top}" == "${name}" ]] && known=1 && break
    done
    if [[ "${known}" -eq 0 ]]; then
        echo "FAIL bare home target: ~/${top}"
        failures=$((failures + 1))
    fi
done < <(cut -d/ -f1 <<< "${targets}" | sort -u)

if [[ "${failures}" -gt 0 ]]; then
    exit 1
fi
echo "ok: every top-level target is a dot entry or a known home folder"
