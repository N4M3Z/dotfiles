#!/bin/bash
# Verify the T3 privacy source files without changing the host.
# These checks compare source files. They do not prove that a host has the policy, that a
# server loaded it, or that a Little Snitch rule group is approved or subscribed.

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
DATA="${ROOT}/.chezmoidata/t3code.json"
WINDOWS="${ROOT}/windows/Install-T3CodePrivacy.ps1"
RULES="${ROOT}/littlesnitch/t3code-telemetry.lsrules"
PRIVACY="${ROOT}/dot_config/zsh/privacy.zsh"
INSTALLER="${ROOT}/run_after_t3code-policy.sh.tmpl"
CLAUDE_SETTINGS="${ROOT}/dot_claude/modify_private_settings.json.tmpl"
# The settings that the Macs and Windows share, with the env block (.chezmoitemplates).
CLAUDE_SETTINGS_SHARED="${ROOT}/.chezmoitemplates/harness/claude-settings.json"
DECISION="${ROOT}/docs/decisions/DOT-0009 T3 Code Telemetry Lockdown.md"
failures=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
skip() { echo "SKIP: $1"; }

for command in jq zsh; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "FAIL: these tests need ${command}"
        exit 1
    }
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/t3code-privacy.XXXXXX")"
trap 'rm -rf "${tmp}"' EXIT

# 1. The shared policy holds each privacy control.
controls=(
    'limits.telemetry is false|.limits.telemetry == false'
    'limits.connect is false|.limits.connect == false'
    'limits.webhookTasks is false|.limits.webhookTasks == false'
    'limits.browserCookieImport is false|.limits.browserCookieImport == false'
    'the preview tunnel stays on: T3 0.1.11 refuses the key, and the tunnel stays between the machines|.limits | has("previewTunnel") | not'
    'agentFeedback is locked off|.settings.agentFeedback | .locked == true and .value.mode == "off"'
    'guestSharingEnabled is locked off|.settings.guestSharingEnabled | .locked == true and .value == false'
    'enableProviderUpdateChecks is locked off|.settings.enableProviderUpdateChecks | .locked == true and .value == false'
    'cloudSpeechCredentials is locked empty|.settings.cloudSpeechCredentials | .locked == true and (.value | keys == ["openai", "openrouter", "xai"] and all(.[]; . == ""))'
    'no provider limit is set before the owner decides|.limits | has("providers") | not'
)
for control in "${controls[@]}"; do
    if jq -e ".t3code.policy | ${control#*|}" "${DATA}" >/dev/null; then
        pass "the shared policy: ${control%%|*}"
    else
        fail "the shared policy: ${control%%|*}"
    fi
done

# 2. The Windows copy of the policy equals the shared policy.
jq -S '.t3code.policy' "${DATA}" > "${tmp}/source.json"
sed -n "/^\$policy = @'/,/^'@/p" "${WINDOWS}" | sed '1d;$d' | jq -S '.' > "${tmp}/windows.json"
if [[ -s "${tmp}/windows.json" ]] && diff -u "${tmp}/source.json" "${tmp}/windows.json"; then
    pass 'the Windows policy equals the shared policy'
else
    fail 'the Windows policy differs from the shared policy'
fi

# 3. The two network source lists hold the same hosts. This is source parity only.
blocked=(
    ingest.t3.codes
    relay.t3.codes
    clerk.t3.codes
    app.t3.codes
    nightly.app.t3.codes
    us-east-1.aws.edge.axiom.co
    api.axiom.co
    clerk-telemetry.com
    statsigapi.net
    api.statsigcdn.com
    featureassets.org
    prodregistryv2.org
)
printf '%s\n' "${blocked[@]}" | sort > "${tmp}/expected-hosts"
jq -r '."denied-remote-hosts"[]' "${RULES}" | sort > "${tmp}/rules-hosts"
sed -n '/^\$blockedHosts = @(/,/^)/p' "${WINDOWS}" | sed '1d;$d' | tr -d "', " | sort > "${tmp}/windows-hosts"
if diff -u "${tmp}/expected-hosts" "${tmp}/rules-hosts"; then
    pass 'the Little Snitch source proposal lists exactly the expected hosts'
else
    fail 'the Little Snitch source proposal differs from the expected hosts'
fi
if diff -u "${tmp}/expected-hosts" "${tmp}/windows-hosts"; then
    pass 'the Windows hosts list holds exactly the expected hosts'
else
    fail 'the Windows hosts list differs from the expected hosts'
fi

# 4. The Little Snitch file stays a source proposal. PROV-0013 rejects hand-written deny rules.
if jq -e '
    (.name | test("proposal"; "i")) and
    (.description | test("not deployed"; "i")) and
    (.description | test("PROV-0013"))
' "${RULES}" >/dev/null; then
    pass 'the Little Snitch file states that it is a proposal and names PROV-0013'
else
    fail 'the Little Snitch file does not state its proposal status'
fi
if grep -qx 'littlesnitch' "${ROOT}/.chezmoiignore"; then
    pass 'chezmoi does not deploy the Little Snitch file'
else
    fail 'chezmoi would deploy the Little Snitch file'
fi

# 5. The Windows installer is a source proposal with three phases. These checks read the script
#    text. No check here runs PowerShell, so they show the structure and not the behavior.
WINDOWS_DIGEST="${WINDOWS}.sha256"
#    The code of each part, without the header, the comment lines, and the here-string bodies:
sed '1,/^#>/d' "${WINDOWS}" | sed "/@'\$/,/^'@/d" | grep -v '^ *#' | grep -v '^[[:space:]]*$' > "${tmp}/windows-code"
sed -n '/^#region user-phase/,/^#endregion user-phase/p' "${WINDOWS}" | grep -v '^ *#' > "${tmp}/user-code"
sed -n '/^#region verify-phase/,/^#endregion verify-phase/p' "${WINDOWS}" | grep -v '^ *#' > "${tmp}/verify-code"
#    The elevated code is every line that runs in the machine phase: all code but the two
#    regions that never run elevated.
sed '1,/^#>/d' "${WINDOWS}" \
    | sed '/^#region user-phase/,/^#endregion user-phase/d' \
    | sed '/^#region verify-phase/,/^#endregion verify-phase/d' \
    | sed "/@'\$/,/^'@/d" | grep -v '^ *#' | grep -v '^[[:space:]]*$' > "${tmp}/elevated-code"
#    The same code without string literals, for the checks on command names.
sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' "${tmp}/elevated-code" > "${tmp}/elevated-bare"
function_body() { sed -n "/^function $1/,/^}/p" "${WINDOWS}"; }
function_body Invoke-MachinePhase > "${tmp}/machine-function"
function_body Install-AdminOnlyFile > "${tmp}/install-function"
function_body Assert-TrustedInvocation > "${tmp}/invocation-function"
function_body Assert-NoRegistryPolicy > "${tmp}/registry-function"
function_body Update-HostsFile > "${tmp}/hosts-function"
grep -oE '^function [A-Za-z0-9-]+' "${WINDOWS}" | cut -d' ' -f2 | sort -u > "${tmp}/local-functions"
line_in() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }
in_order() {
    local file="$1" previous=0 line
    shift
    for text in "$@"; do
        line="$(line_in "${file}" "${text}")"
        [[ -n "${line}" && "${line}" -gt "${previous}" ]] || return 1
        previous="${line}"
    done
}

if [[ -s "${tmp}/user-code" && -s "${tmp}/verify-code" && -s "${tmp}/elevated-code" \
    && -s "${tmp}/machine-function" && -s "${tmp}/hosts-function" && -s "${tmp}/registry-function" ]]; then
    pass 'the Windows installer has a user phase, a machine phase, and a verify phase'
else
    fail 'the Windows installer does not have the three phases'
fi

# 5a. The reviewed artifact. The digest file must match the script, and the script must demand
#     the staging folder. The script cannot prove its own integrity, and it must say so.
if [[ -f "${WINDOWS_DIGEST}" ]] \
    && [[ "$(cut -d' ' -f1 "${WINDOWS_DIGEST}")" == "$(shasum -a 256 "${WINDOWS}" | cut -d' ' -f1)" ]]; then
    pass 'the digest file matches the Windows installer'
else
    fail 'the digest file is missing or does not match the Windows installer'
fi
if in_order "${tmp}/invocation-function" "\$PSVersionTable.PSEdition -ne 'Desktop'" \
    "[Environment]::SystemDirectory, 'WindowsPowerShell', 'v1.0', 'powershell.exe'" \
    "-notcontains '-NoProfile'" '[string]::Equals($PSCommandPath, $stagedScript' \
    'Assert-AdminOnlyWrite $stagingDir' 'Assert-AdminOnlyWrite $stagedScript' \
    'Get-Sha256Hex ([IO.File]::ReadAllBytes($stagedScript))' \
    '$ExpectedScriptSha256.ToLowerInvariant() -ne $scriptDigest' \
    && grep -qF "\$stagedScript = 'C:\\Program Files\\T3CodePrivacy\\Install-T3CodePrivacy.ps1'" "${tmp}/elevated-code"; then
    pass 'the machine phase demands the system shell, no profile, the staging folder, and the reviewed digest'
else
    fail 'the machine phase does not demand the staging folder and the reviewed digest'
fi
header="$(sed -n '1,/^#>/p' "${WINDOWS}")"
header_statements=(
    'signed commit'
    'does not prove its own'
    'only administrator accounts can change'
    '-NoProfile'
    'C:\Program Files\T3CodePrivacy'
    'never run on Windows'
    'not a trust boundary'
)
for statement in "${header_statements[@]}"; do
    if grep -qF -- "${statement}" <<< "${header}"; then
        pass "the Windows installer header states: ${statement}"
    else
        fail "the Windows installer header does not state: ${statement}"
    fi
done

# 5b. The elevated code uses .NET calls and the functions of the script only. A cmdlet, an
#     alias, a program, a pipeline, or a second statement on a line fails these checks.
unknown_commands="$(grep -oE '[A-Z][A-Za-z]*-[A-Z][A-Za-z0-9]+' "${tmp}/elevated-bare" | sort -u \
    | grep -vxFf "${tmp}/local-functions" || true)"
if [[ -z "${unknown_commands}" ]]; then
    pass 'the elevated Windows code calls no cmdlet'
else
    fail "the elevated Windows code calls a command that the script does not define: ${unknown_commands//$'\n'/ }"
fi
keywords='if|elseif|else|foreach|while|try|catch|finally|throw|return|continue|function|param'
bad_starts="$(sed -E 's/^[[:space:]]+//' "${tmp}/elevated-code" \
    | grep -vE "^[]\$[{}()'\"@+-]" \
    | grep -vE "^(${keywords})([^A-Za-z0-9-]|\$)" \
    | grep -oE '^[A-Za-z0-9._-]+' | sort -u | grep -vxFf "${tmp}/local-functions" || true)"
if [[ -z "${bad_starts}" ]]; then
    pass 'each elevated statement starts with a variable, a type, a keyword, or a function of the script'
else
    fail "an elevated statement starts with an alias or a program: ${bad_starts//$'\n'/ }"
fi
if grep -qE '[|;&]' "${tmp}/elevated-bare"; then
    fail 'the elevated Windows code holds a pipeline, a second statement on a line, or a call operator'
else
    pass 'the elevated Windows code holds no pipeline, no second statement on a line, and no call operator'
fi
if grep -qiE '\$env:|GetEnvironmentVariable|ExpandEnvironmentVariables|GetTempPath|ProgramFiles|SystemRoot|windir|\$t3|policy check' "${tmp}/elevated-code"; then
    fail 'the elevated Windows code uses an environment variable, TEMP, or the t3 command'
else
    pass 'the elevated Windows code uses no environment variable, no TEMP folder, and no t3 command'
fi
if grep -qF '#Requires -RunAsAdministrator' "${WINDOWS}"; then
    fail 'the Windows installer forces elevation for the phase that starts the t3 command'
else
    pass 'the Windows installer does not force elevation for the user phase'
fi

# 5c. Only the user phase starts the t3 command, and it refuses elevation first.
if [[ "$(grep -c 'Get-Command t3' "${tmp}/windows-code")" == "1" ]] \
    && [[ "$(grep -c 'Get-Command t3' "${tmp}/user-code")" == "1" ]] \
    && [[ "$(grep -c 'policy check \$candidate' "${tmp}/windows-code")" == "1" ]] \
    && [[ "$(grep -c 'policy check \$candidate' "${tmp}/user-code")" == "1" ]]; then
    pass 'only the user phase starts the t3 command'
else
    fail 'the t3 command starts outside the user phase'
fi
if in_order "${tmp}/user-code" 'if (Test-Elevated)' 'Get-Command t3' 'The t3 command is not available' \
    'WriteAllBytes($candidate, $policyBytes)' 'policy check $candidate' 'SetEnvironmentVariable' \
    'Get-Sha256Hex $policyBytes' 'not a trust boundary'; then
    pass 'the user phase refuses elevation, stops without t3, and checks the policy before it changes a setting'
else
    fail 'the user phase does not refuse elevation or does not check the policy first'
fi

# 5d. The machine phase does every check before the first write.
if in_order "${tmp}/machine-function" 'if (-not (Test-Elevated))' 'Assert-TrustedInvocation' \
    'Get-Sha256Hex $policyBytes' '$ValidatedPolicySha256.ToLowerInvariant() -ne $digest' \
    'Assert-NoRegistryPolicy' 'Initialize-AdminOnlyDirectory $policyDir' \
    'Initialize-AdminOnlyDirectory $claudeDropInDir' 'Install-AdminOnlyFile $policyFile $policyBytes' \
    'Install-AdminOnlyFile $claudeDropInFile $claudeSettingsBytes' 'Update-HostsFile'; then
    pass 'the machine phase checks the invocation, the digests, and the registry before it writes a file'
else
    fail 'the machine phase can write a file before a check'
fi
if grep -qF '$policyBytes = $utf8.GetBytes(($policy -replace' "${tmp}/windows-code" \
    && [[ "$(grep -c 'GetBytes(' "${tmp}/elevated-code")" == "3" ]]; then
    pass 'both phases use the same policy bytes'
else
    fail 'the phases can use different policy bytes'
fi

# 5e. Every registry policy source stops the machine phase: a value, a subkey, in both views.
if in_order "${tmp}/registry-function" '[Microsoft.Win32.RegistryView]::Registry64' \
    '$hive.OpenSubKey($registryPolicyKey)' '$key.ValueCount -gt 0 -or $key.SubKeyCount -gt 0' 'throw' \
    && grep -qF '[Microsoft.Win32.RegistryView]::Registry32' "${tmp}/registry-function" \
    && grep -qF "\$registryPolicyKey = 'SOFTWARE\\Policies\\T3Tools\\T3Code'" "${tmp}/elevated-code" \
    && ! grep -qiE "Name Policy|GetValue\('Policy'\)" "${tmp}/elevated-code"; then
    pass 'the machine phase stops on any value or subkey of the registry policy key'
else
    fail 'the registry check does not cover every policy source'
fi

# 5f. Literal install targets and administrator-only files.
if grep -qF "\$policyFile = 'C:\\Program Files\\T3Code\\policy.json'" "${tmp}/elevated-code" \
    && grep -qF "\$claudeDropInFile = 'C:\\Program Files\\ClaudeCode\\managed-settings.d\\90-t3code-privacy.json'" "${tmp}/elevated-code"; then
    pass 'the Windows policy and Claude settings targets are literal paths'
else
    fail 'a Windows install target is not a literal path'
fi
if grep -qF 'SetAccessRuleProtection($true, $false)' "${tmp}/elevated-code" \
    && in_order "${tmp}/install-function" 'WriteAllBytes($staged, $Bytes)' 'Set-AdminOnlyAcl $staged' \
        'Test-ReparsePoint $Target' '[IO.File]::Replace($staged, $Target' 'Set-AdminOnlyAcl $Target' \
        'Assert-AdminOnlyWrite $Target' 'ReadAllBytes($Target)'; then
    pass 'the Windows installer stages in the target folder, sets administrator-only permissions, and reads the file back'
else
    fail 'the Windows installer does not set and verify the installed file permissions'
fi

# 5g. The hosts update: trusted folder, link and permission checks, conflict rejection, one
#     canonical entry, backup, permissions, and a reread of the final bytes.
if in_order "${tmp}/hosts-function" "[IO.Path]::Combine([Environment]::SystemDirectory, 'drivers', 'etc')" \
    'Assert-AdminOnlyWrite $etcDir' 'Assert-AdminOnlyWrite $hostsFile' \
    '$originalBytes = [IO.File]::ReadAllBytes($hostsFile)' \
    'if ($blockedAddresses -notcontains $address)' 'maps a blocked hostname to another address' \
    'if ($otherNames -gt 0)' 'a blocked hostname and another hostname' \
    'if (-not $Remove)' '$kept.Add($canonical +' \
    '[IO.File]::WriteAllBytes($backup, $originalBytes)' 'ReadAllBytes($backup)' \
    '[IO.File]::WriteAllBytes($hostsFile, $newBytes)' 'Set-HostsAcl $hostsFile' \
    'ReadAllBytes($hostsFile))) -ne (Get-Sha256Hex $newBytes)' \
    && [[ "$(grep -cF 'Assert-AdminOnlyWrite $hostsFile' "${tmp}/hosts-function")" == "2" ]] \
    && [[ "$(grep -nF 'Assert-AdminOnlyWrite $hostsFile' "${tmp}/hosts-function" | tail -1 | cut -d: -f1)" \
        -gt "$(line_in "${tmp}/hosts-function" 'Set-HostsAcl $hostsFile')" ]]; then
    pass 'the hosts update checks links and permissions, rejects a conflicting mapping, backs up, and rereads the file'
else
    fail 'the hosts update misses a check, the conflict rejection, the backup, or the reread'
fi
if [[ "$(grep -c 'WriteAllBytes(\$hostsFile' "${tmp}/elevated-code")" == "1" ]] \
    && grep -qF 'if (Test-ReparsePoint $Path)' "${tmp}/elevated-code" \
    && grep -qF "\$blockedAddress = '0.0.0.0'" "${tmp}/elevated-code" \
    && grep -qF "\$blockedAddresses = @(\$blockedAddress, '::')" "${tmp}/elevated-code" \
    && ! grep -qiE 'Add-Content|AppendAllText|AppendAllLines' "${tmp}/elevated-code"; then
    pass 'the hosts file gets one full write with the IPv4 and IPv6 canonical addresses, never an append'
else
    fail 'the hosts file can get an append or a second write, or misses the IPv6 address'
fi

# 5g'. The Remove phase undoes the machine phase with the same invocation checks.
function_body Invoke-RemovePhase > "${tmp}/remove-function"
function_body Remove-AdminOnlyFile > "${tmp}/remove-file-function"
if in_order "${tmp}/remove-function" 'if (-not (Test-Elevated))' 'Assert-TrustedInvocation' \
    'Remove-AdminOnlyFile $policyFile' 'Remove-AdminOnlyFile $claudeDropInFile' 'Update-HostsFile $true' \
    && grep -qF "[ValidateSet('User', 'Machine', 'Verify', 'Remove')]" "${WINDOWS}" \
    && in_order "${tmp}/remove-file-function" 'Test-ReparsePoint $Target' '[IO.File]::Delete($Target)'; then
    pass 'the Remove phase checks the invocation, refuses a link, and deletes the files and the host entries'
else
    fail 'the Remove phase misses a check or a step'
fi

# 5h. The verify phase runs without elevation and checks the address of each blocked hostname.
if in_order "${tmp}/verify-code" 'if (Test-Elevated)' '[Net.Dns]::GetHostAddresses($blocked)' \
    '$blockedAddresses -notcontains $address.ToString()' 't3 policy show' 'DO_NOT_TRACK'; then
    pass 'the verify phase refuses elevation, checks each blocked hostname, and names the live checks'
else
    fail 'the verify phase does not check the hostnames or does not name the live checks'
fi

# 5i. The Claude Code managed settings file holds the env block only, so it removes no other
#     setting. It holds DO_NOT_TRACK and the three Claude Code switches.
sed -n "/^\$claudeSettings = @'/,/^'@/p" "${WINDOWS}" | sed '1d;$d' > "${tmp}/windows-claude.json"
if jq -e '. == {env: {
    DO_NOT_TRACK: "1",
    DISABLE_FEEDBACK_COMMAND: "1",
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY: "1",
    DISABLE_ERROR_REPORTING: "1"
}}' "${tmp}/windows-claude.json" >/dev/null 2>&1; then
    pass 'the Windows Claude managed settings hold exactly DO_NOT_TRACK and the three switches in an env block'
else
    fail 'the Windows Claude managed settings differ from DO_NOT_TRACK and the three switches'
fi
if grep -qiE 'not verified on Apex|No run on Apex' "${WINDOWS}"; then
    pass 'the Windows installer states that the Claude managed settings path is not verified on Apex'
else
    fail 'the Windows installer does not state that the Claude managed settings path is unverified'
fi

# 6. The shell source sets every switch and states the effect of DO_NOT_TRACK.
values="$(zsh -f -c '
    source "$1"
    print -r -- "$T3CODE_TELEMETRY_ENABLED|$DO_NOT_TRACK|$DISABLE_FEEDBACK_COMMAND|$CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY|$DISABLE_ERROR_REPORTING"
' _ "${PRIVACY}")"
if [[ "${values}" == "false|1|1|1|1" ]]; then
    pass 'the shell source sets every privacy switch'
else
    fail "the shell source returned unexpected values: ${values}"
fi
if grep -q 'turns off Claude Code telemetry and feature-flag' "${PRIVACY}"; then
    pass 'the shell source states that DO_NOT_TRACK turns off Claude Code telemetry and feature flags'
else
    fail 'the shell source does not state the Claude Code effect of DO_NOT_TRACK'
fi
for file in "${PRIVACY}" "${DECISION}" "${WINDOWS}"; do
    if grep -qiE 'feature flags (working|stay|remain|keep)|keep(s)? .*feature flags' "${file}"; then
        fail "$(basename "${file}") claims that Claude Code feature flags stay active"
    else
        pass "$(basename "${file}") does not claim that Claude Code feature flags stay active"
    fi
done

# 7. The Claude settings env block carries the three switches that the login shell cannot give
#    to T3 Code threads.
switches=(DISABLE_FEEDBACK_COMMAND CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY DISABLE_ERROR_REPORTING)
sed -n '/^  "env": {/,/^  },/p' "${CLAUDE_SETTINGS_SHARED}" > "${tmp}/env-block"
for switch in "${switches[@]}"; do
    if grep -qF "\"${switch}\": \"1\"," "${tmp}/env-block"; then
        pass "the Claude settings template sets ${switch} in its env block"
    else
        fail "the Claude settings template does not set ${switch} in its env block"
    fi
done

if command -v chezmoi >/dev/null 2>&1; then
    if chezmoi execute-template --source "${ROOT}" < "${CLAUDE_SETTINGS}" > "${tmp}/claude-settings.sh" 2>"${tmp}/render.err" \
        && printf '' | bash "${tmp}/claude-settings.sh" > "${tmp}/claude-settings.json" 2>>"${tmp}/render.err" \
        && jq -e '
            .env.DISABLE_FEEDBACK_COMMAND == "1" and
            .env.CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY == "1" and
            .env.DISABLE_ERROR_REPORTING == "1"
        ' "${tmp}/claude-settings.json" >/dev/null; then
        pass 'the rendered Claude settings hold the three switches'
    else
        fail 'the rendered Claude settings do not hold the three switches'
        cat "${tmp}/render.err"
    fi

    # 8. The Mac and Linux installer cannot install an unchecked policy. The stubs replace sudo
    #    and t3, so no host file changes.
    stubs="${tmp}/stubs"
    mkdir -p "${stubs}"
    printf '#!/bin/sh\necho "$@" >> "%s"\n' "${tmp}/sudo.log" > "${stubs}/sudo"
    chmod +x "${stubs}/sudo"
    run_installer() {
        rm -f "${tmp}/sudo.log"
        env -i HOME="${tmp}" TMPDIR="${tmp}" PATH="${stubs}:/usr/bin:/bin" \
            T3CODE_POLICY_FILE="${tmp}/installed/policy.json" \
            bash "${tmp}/installer.sh" >/dev/null 2>&1
    }
    if chezmoi execute-template --source "${ROOT}" < "${INSTALLER}" > "${tmp}/installer.sh" 2>"${tmp}/render.err" \
        && [[ -s "${tmp}/installer.sh" ]]; then
        rm -f "${stubs}/t3"
        if run_installer; then
            fail 'the installer continues when the t3 command is not available'
        elif [[ -e "${tmp}/sudo.log" ]]; then
            fail 'the installer starts an install when the t3 command is not available'
        else
            pass 'the installer stops and installs nothing when the t3 command is not available'
        fi

        printf '#!/bin/sh\nexit 1\n' > "${stubs}/t3"
        chmod +x "${stubs}/t3"
        if run_installer || [[ -e "${tmp}/sudo.log" ]]; then
            fail 'the installer starts an install after t3 rejects the policy'
        else
            pass 'the installer stops and installs nothing when t3 rejects the policy'
        fi

        printf '#!/bin/sh\nexit 0\n' > "${stubs}/t3"
        if run_installer && grep -q 'install -m 644' "${tmp}/sudo.log" 2>/dev/null; then
            pass 'the installer starts an install only after t3 accepts the policy'
        else
            fail 'the installer does not start an install after t3 accepts the policy'
        fi

        # An older build of this account that refuses the policy stops the install, as T3
        # 0.1.11 refused a key that 0.1.13 accepted.
        mkdir -p "${tmp}/.t3/runtime/versions/0.1.11"
        printf '#!/bin/sh\nexit 77\n' > "${tmp}/.t3/runtime/versions/0.1.11/t3"
        chmod +x "${tmp}/.t3/runtime/versions/0.1.11/t3"
        if run_installer || [[ -e "${tmp}/sudo.log" ]]; then
            fail 'the installer starts an install although an installed T3 version refuses the policy'
        else
            pass 'the installer stops when any T3 version of this account refuses the policy'
        fi
        rm -rf "${tmp}/.t3"

        # An account without administrator rights reports that and lets the apply go on.
        printf '#!/bin/sh\ncase "$1" in -Gn) echo "staff everyone" ;; -un) echo agents ;; esac\n' > "${stubs}/id"
        chmod +x "${stubs}/id"
        if run_installer && [[ ! -e "${tmp}/sudo.log" ]]; then
            pass 'the installer installs nothing and does not fail the apply for an account without administrator rights'
        else
            fail 'the installer fails the apply or calls sudo for an account without administrator rights'
        fi
        rm -f "${stubs}/id"

        # The rendered policy is what the installer would write. It must equal the shared policy.
        sed -n "/^cat >| \"\$policy\" <<'POLICY'/,/^POLICY/p" "${tmp}/installer.sh" | sed '1d;$d' > "${tmp}/rendered-policy.json"
        if jq -S '.' "${tmp}/rendered-policy.json" 2>/dev/null | diff -u "${tmp}/source.json" - >/dev/null; then
            pass 'the installer policy equals the shared policy'
        else
            fail 'the installer policy differs from the shared policy'
        fi

        mkdir -p "${tmp}/installed"
        cp "${tmp}/rendered-policy.json" "${tmp}/installed/policy.json"
        rm -f "${stubs}/t3"
        if run_installer && [[ ! -e "${tmp}/sudo.log" ]]; then
            pass 'the installer changes nothing when the installed policy is already identical'
        else
            fail 'the installer fails or reinstalls when the installed policy is already identical'
        fi
    else
        fail 'the installer template does not render'
        cat "${tmp}/render.err"
    fi
else
    skip 'chezmoi is not installed: the rendered Claude settings and the installer were not run'
fi

# 9. The decision record keeps the limits of this work visible.
decision_statements=(
    'PROV-0013'
    'T3 agent feedback only'
    't3 policy show'
    'source proposal'
    'The owner requires'
    'Completion blockers'
    'never starts the `t3` command'
    'signed'
    'does not prove its own integrity'
    'not a trust boundary'
    'No run on Apex has confirmed'
    'No PowerShell has parsed or run the script'
    '`DO_NOT_TRACK` and the three Claude Code switches'
)
for statement in "${decision_statements[@]}"; do
    if grep -qF -- "${statement}" "${DECISION}"; then
        pass "DOT-0009 states: ${statement}"
    else
        fail "DOT-0009 does not state: ${statement}"
    fi
done

# 10. The installed T3 build accepts the shared policy. This checks the file, not a running server.
if command -v t3 >/dev/null 2>&1; then
    jq -c '.t3code.policy' "${DATA}" > "${tmp}/policy.json"
    if t3 policy check "${tmp}/policy.json" >/dev/null 2>&1; then
        pass 'the installed T3 build accepts the policy file'
    else
        fail 'the installed T3 build rejects the policy file'
    fi
else
    skip 't3 is not installed: no T3 build checked the policy file'
fi

if [[ ${failures} -gt 0 ]]; then
    echo "${failures} test(s) failed"
    exit 1
fi
echo 'All T3 privacy source checks passed. They do not prove deployment or approval.'
