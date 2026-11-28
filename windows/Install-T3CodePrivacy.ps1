<#
Source proposal. This script has never run on Windows, and no PowerShell has parsed it.

Installs the T3 Code privacy settings on a Windows machine, such as Apex. chezmoi does not run
there, so this script carries the same settings as run_after_t3code-policy.sh.tmpl,
dot_config/zsh/privacy.zsh, and the env block in dot_claude/modify_private_settings.json.tmpl.
Decision: docs/decisions/DOT-0009.

Prerequisite. The owner reviews this file at a signed commit and takes the SHA-256 digest of the
file from Install-T3CodePrivacy.ps1.sha256 in that commit. The script does not prove its own
integrity: a changed copy can remove each check below. The proof is the review of the digest
by the owner, and a staging folder that only administrator accounts can change.

The owner starts each step with the Windows PowerShell of the system and no profile:
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script> <arguments>

1. User phase, not elevated, as the user who runs T3 Code:
       -File <script> -Phase User
   It checks the policy with the t3 command of that user, sets the user variables, and prints
   the SHA-256 digest of the policy. This digest shows that t3 checked the policy bytes. It is
   not a trust boundary for the elevated phase.
2. Staging, in an elevated shell. Make the folder C:\Program Files\T3CodePrivacy, copy this
   file into it, and compute the SHA-256 digest of the copy. Compare it with the digest from
   the signed commit. Stop when they differ.
3. Machine phase, elevated, from the staging folder:
       -File "C:\Program Files\T3CodePrivacy\Install-T3CodePrivacy.ps1" -Phase Machine -ExpectedScriptSha256 <script digest> -ValidatedPolicySha256 <policy digest>
   It installs the policy file, a Claude Code managed settings file, and the hosts entries.
   It starts no program, and it uses .NET calls only: no cmdlet, alias, or module lookup.
4. Verify phase, not elevated:
       -File <script> -Phase Verify
   It checks that each blocked hostname resolves to 0.0.0.0 or :: and prints the manual checks.

To undo the install, for example when a T3 update refuses the policy and T3 does not start, run
the Remove phase, elevated, from the staging folder:
       -File "C:\Program Files\T3CodePrivacy\Install-T3CodePrivacy.ps1" -Phase Remove -ExpectedScriptSha256 <script digest>
It deletes the policy file and the Claude Code managed settings file, and removes the blocked
hostnames from the hosts file. It keeps a backup of the hosts file. The user variables stay.

Files on disk do not prove what a running program loaded. After the machine phase, quit and
reopen T3 Code and run `t3 policy show`. Then start a Claude thread in T3 Code and confirm that
it has DO_NOT_TRACK and the three Claude Code switches. No run on Apex has yet confirmed that
Claude Code reads the managed settings file below, or how it ranks other managed sources.
Keep the policy below identical to .chezmoidata/t3code.json.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('User', 'Machine', 'Verify', 'Remove')]
    [string]$Phase,

    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedScriptSha256,

    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ValidatedPolicySha256
)
$ErrorActionPreference = 'Stop'

# The managed policy. T3 Code refuses to start when a machine has both a policy file and a
# registry policy, so this script uses the file only.
$policy = @'
{
  "schemaVersion": 1,
  "organization": "N4M3Z",
  "settings": {
    "agentFeedback": { "value": { "mode": "off" }, "locked": true },
    "cloudSpeechCredentials": {
      "value": { "openai": "", "xai": "", "openrouter": "" },
      "locked": true
    },
    "enableProviderUpdateChecks": { "value": false, "locked": true },
    "guestSharingEnabled": { "value": false, "locked": true }
  },
  "limits": {
    "browserCookieImport": false,
    "connect": false,
    "telemetry": false,
    "webhookTasks": false
  }
}
'@

# Claude Code managed settings. User variables do not reach each Claude session that T3 Code
# starts, so the four switches also go into a managed settings file. The file holds the env
# block only. The Claude Code documentation says that this block merges key by key with other
# managed settings files. That is not verified on Apex.
$claudeSettings = @'
{
  "env": {
    "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY": "1",
    "DISABLE_ERROR_REPORTING": "1",
    "DISABLE_FEEDBACK_COMMAND": "1",
    "DO_NOT_TRACK": "1"
  }
}
'@

# The digests and the installed files use these exact bytes: UTF-8, no byte order mark, and
# LF line ends.
$utf8 = [Text.UTF8Encoding]::new($false)
$policyBytes = $utf8.GetBytes(($policy -replace "`r`n", "`n"))
$claudeSettingsBytes = $utf8.GetBytes(($claudeSettings -replace "`r`n", "`n"))

# The hosts file holds the same list as the Little Snitch source proposal. Windows Firewall
# cannot block by hostname. A hosts entry gives no connection record.
$blockedHosts = @(
    'ingest.t3.codes',
    'relay.t3.codes',
    'clerk.t3.codes',
    'app.t3.codes',
    'nightly.app.t3.codes',
    'us-east-1.aws.edge.axiom.co',
    'api.axiom.co',
    'clerk-telemetry.com',
    'statsigapi.net',
    'api.statsigcdn.com',
    'featureassets.org',
    'prodregistryv2.org'
)
$blockedAddress = '0.0.0.0'
# A name with an AAAA record still resolves over IPv6 unless the hosts file also maps it to ::.
$blockedAddresses = @($blockedAddress, '::')

#region machine-phase
# This region runs elevated. It uses .NET calls and the functions of this file only. It starts
# no program, and it builds no path from an environment variable: a user can point a variable
# at a folder that the user can write.

# The machine phase runs only from this literal staging folder.
$programRoot = 'C:\Program Files'
$stagingDir = 'C:\Program Files\T3CodePrivacy'
$stagedScript = 'C:\Program Files\T3CodePrivacy\Install-T3CodePrivacy.ps1'
# T3 Code reads the policy from this literal path.
$policyDir = 'C:\Program Files\T3Code'
$policyFile = 'C:\Program Files\T3Code\policy.json'
# The Claude Code documentation names this folder for managed settings files.
$claudeDir = 'C:\Program Files\ClaudeCode'
$claudeDropInDir = 'C:\Program Files\ClaudeCode\managed-settings.d'
$claudeDropInFile = 'C:\Program Files\ClaudeCode\managed-settings.d\90-t3code-privacy.json'
# T3 Code also reads a policy from this registry key. Any value or subkey there is a policy source.
$registryPolicyKey = 'SOFTWARE\Policies\T3Tools\T3Code'

# Only these accounts may change the installed files: Administrators, SYSTEM, and TrustedInstaller.
$administrators = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$users = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
$appPackages = [Security.Principal.SecurityIdentifier]::new('S-1-15-2-1')
$restrictedAppPackages = [Security.Principal.SecurityIdentifier]::new('S-1-15-2-2')
$trustedWriters = @(
    'S-1-5-32-544',
    'S-1-5-18',
    'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
)
$writeRights = [Security.AccessControl.FileSystemRights]'WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership'
# The specific write rights, plus the generic GENERIC_ALL and GENERIC_WRITE bits.
$writeMask = [int]$writeRights -bor 0x50000000

function Write-Line([string]$Text) {
    [Console]::Out.WriteLine($Text)
}

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Test-Elevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ReparsePoint([string]$Path) {
    return [IO.File]::GetAttributes($Path).HasFlag([IO.FileAttributes]::ReparsePoint)
}

function Get-PathSecurity([string]$Path) {
    if ([IO.Directory]::Exists($Path)) {
        return [IO.DirectoryInfo]::new($Path).GetAccessControl()
    }
    return [IO.FileInfo]::new($Path).GetAccessControl()
}

function Assert-AdminOnlyWrite([string]$Path) {
    # Stop when the item is a link, or when an account outside the trusted list owns the item
    # or can change it.
    if (Test-ReparsePoint $Path) {
        throw "$Path is a link to another place. Nothing more was changed."
    }
    $acl = Get-PathSecurity $Path
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($trustedWriters -notcontains $owner) {
        throw "$Path has an owner that is not an administrator account. Nothing more was changed."
    }
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        $account = $rule.IdentityReference.Value
        # CREATOR OWNER (S-1-3-0) gives rights only to the account that creates a new item.
        if ($rule.AccessControlType -ne 'Allow' -or $account -eq 'S-1-3-0') {
            continue
        }
        $canWrite = (([int]$rule.FileSystemRights) -band $writeMask) -ne 0
        if ($canWrite -and $trustedWriters -notcontains $account) {
            throw "$Path lets the account $account change it. Nothing more was changed."
        }
    }
}

function Set-AdminOnlyAcl([string]$Path) {
    # Replace every permission. Administrators and SYSTEM get full control, and users can read.
    $acl = [Security.AccessControl.FileSecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($administrators)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($administrators, 'FullControl', 'Allow'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($system, 'FullControl', 'Allow'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($users, 'ReadAndExecute', 'Allow'))
    [IO.FileInfo]::new($Path).SetAccessControl($acl)
}

function Set-HostsAcl([string]$Path) {
    # The same permissions as the Windows default for the hosts file, as explicit entries.
    # Programs that resolve names need read access. The owner of the file does not change.
    $acl = [Security.AccessControl.FileSecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($administrators, 'FullControl', 'Allow'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($system, 'FullControl', 'Allow'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($users, 'ReadAndExecute', 'Allow'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($appPackages, 'ReadAndExecute', 'Allow'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($restrictedAppPackages, 'ReadAndExecute', 'Allow'))
    [IO.FileInfo]::new($Path).SetAccessControl($acl)
}

function Assert-TrustedInvocation {
    # These checks find a wrong shell, a session with a profile, a wrong folder, or a stale
    # copy. They are not proof: a changed script can remove its own checks. The proof is the
    # digest review by the owner before this phase starts.
    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        throw 'Run the Machine phase in the Windows PowerShell 5.1 of the system. No file was installed.'
    }
    $shell = [IO.Path]::Combine([Environment]::SystemDirectory, 'WindowsPowerShell', 'v1.0', 'powershell.exe')
    $process = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if (-not [string]::Equals($process, $shell, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Run the Machine phase with the 64-bit powershell.exe in the system folder. No file was installed.'
    }
    $arguments = [Environment]::GetCommandLineArgs()
    if ($arguments -notcontains '-NoProfile' -or $arguments -notcontains '-File') {
        throw 'Run the Machine phase with -NoProfile and -File. No file was installed.'
    }
    if (-not [string]::Equals($PSCommandPath, $stagedScript, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Run the Machine phase from $stagedScript. No file was installed."
    }
    Assert-AdminOnlyWrite $programRoot
    Assert-AdminOnlyWrite $stagingDir
    Assert-AdminOnlyWrite $stagedScript
    $scriptDigest = Get-Sha256Hex ([IO.File]::ReadAllBytes($stagedScript))
    if (-not $ExpectedScriptSha256 -or $ExpectedScriptSha256.ToLowerInvariant() -ne $scriptDigest) {
        throw 'The digest of this script is not the digest that the owner reviewed. No file was installed.'
    }
}

function Assert-NoRegistryPolicy {
    # T3 Code reads a Policy value, single values, and list subkeys from this key. Each one is
    # a policy source, and T3 Code does not start with a file policy and a registry policy.
    foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)) {
        $hive = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view)
        try {
            $key = $hive.OpenSubKey($registryPolicyKey)
            if ($null -ne $key) {
                try {
                    if ($key.ValueCount -gt 0 -or $key.SubKeyCount -gt 0) {
                        throw "The registry key HKLM\$registryPolicyKey holds a value or a subkey. Remove each one first. No file was installed."
                    }
                }
                finally {
                    $key.Dispose()
                }
            }
        }
        finally {
            $hive.Dispose()
        }
    }
}

function Initialize-AdminOnlyDirectory([string]$Path) {
    if (-not [IO.Directory]::Exists($Path)) {
        if ([IO.File]::Exists($Path)) {
            throw "$Path is not a folder. No file was installed."
        }
        $null = [IO.Directory]::CreateDirectory($Path)
    }
    Assert-AdminOnlyWrite $Path
}

function Install-AdminOnlyFile([string]$Target, [byte[]]$Bytes) {
    # Stage the file in the target folder, not in TEMP. A file that moves out of TEMP keeps the
    # TEMP permissions, and those permissions let the user change the file.
    $staged = $Target + '.staged.' + [guid]::NewGuid().ToString('N')
    try {
        [IO.File]::WriteAllBytes($staged, $Bytes)
        Set-AdminOnlyAcl $staged
        if ([IO.File]::Exists($Target)) {
            if (Test-ReparsePoint $Target) {
                throw "$Target is a link to another place. It was not replaced."
            }
            [IO.File]::Replace($staged, $Target, [NullString]::Value)
        }
        else {
            [IO.File]::Move($staged, $Target)
        }
    }
    finally {
        if ([IO.File]::Exists($staged)) {
            [IO.File]::Delete($staged)
        }
    }
    Set-AdminOnlyAcl $Target
    Assert-AdminOnlyWrite $Target
    if ((Get-Sha256Hex ([IO.File]::ReadAllBytes($Target))) -ne (Get-Sha256Hex $Bytes)) {
        throw "$Target does not hold the expected content."
    }
    Write-Line "Installed $Target. Only administrator accounts can change it."
}

function Update-HostsFile([bool]$Remove) {
    # With $Remove false, each blocked hostname ends with one entry for each blocked address.
    # With $Remove true, no blocked hostname stays. Each other line keeps its exact bytes.
    # The system folder comes from the Windows API, not from an environment variable.
    $etcDir = [IO.Path]::Combine([Environment]::SystemDirectory, 'drivers', 'etc')
    $hostsFile = [IO.Path]::Combine($etcDir, 'hosts')
    Assert-AdminOnlyWrite $etcDir
    if (-not [IO.File]::Exists($hostsFile)) {
        throw "$hostsFile does not exist. The hosts file was not changed."
    }
    Assert-AdminOnlyWrite $hostsFile

    # Latin-1 maps each byte to one character, so each line that stays keeps its exact bytes.
    $latin1 = [Text.Encoding]::GetEncoding(28591)
    $originalBytes = [IO.File]::ReadAllBytes($hostsFile)
    $kept = [Collections.Generic.List[string]]::new()
    foreach ($line in $latin1.GetString($originalBytes).Split("`n")) {
        $text = $line.TrimEnd("`r")
        $mapping = ($text -split '#', 2)[0].Trim()
        $tokens = @(($mapping -split '\s+') -ne '')
        # The first token of a mapping is the address. Each other token is a hostname.
        $address = $null
        $blockedNames = 0
        $otherNames = 0
        foreach ($token in $tokens) {
            if ($null -eq $address) {
                $address = $token
                continue
            }
            if ($blockedHosts -contains $token.TrimEnd('.')) {
                $blockedNames++
            }
            else {
                $otherNames++
            }
        }
        if ($blockedNames -eq 0) {
            $kept.Add($text)
            continue
        }
        # A blocked hostname must have no mapping but a canonical one. A canonical line is
        # dropped here, and the install adds each canonical line again below.
        if ($blockedAddresses -notcontains $address) {
            throw 'The hosts file maps a blocked hostname to another address. Remove that line by hand. The hosts file was not changed.'
        }
        if ($otherNames -gt 0) {
            throw 'The hosts file has a line with a blocked hostname and another hostname. Split that line by hand. The hosts file was not changed.'
        }
    }
    while ($kept.Count -gt 0 -and $kept[$kept.Count - 1].Trim() -eq '') {
        $kept.RemoveAt($kept.Count - 1)
    }
    # One canonical entry for each blocked hostname and each blocked address.
    if (-not $Remove) {
        foreach ($blocked in $blockedHosts) {
            foreach ($canonical in $blockedAddresses) {
                $kept.Add($canonical + ' ' + $blocked + '  # T3 Code telemetry block (DOT-0009)')
            }
        }
    }
    $newBytes = $latin1.GetBytes([string]::Join("`r`n", $kept.ToArray()) + "`r`n")

    if ((Get-Sha256Hex $newBytes) -ne (Get-Sha256Hex $originalBytes)) {
        # Keep the exact old bytes next to the hosts file before the write.
        $backup = $hostsFile + '.t3code-backup-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N')
        [IO.File]::WriteAllBytes($backup, $originalBytes)
        if ((Get-Sha256Hex ([IO.File]::ReadAllBytes($backup))) -ne (Get-Sha256Hex $originalBytes)) {
            throw "The backup $backup does not hold the old hosts file. The hosts file was not changed."
        }
        Assert-AdminOnlyWrite $backup
        [IO.File]::WriteAllBytes($hostsFile, $newBytes)
        Write-Line "Wrote $hostsFile. The old file is in $backup."
    }
    Set-HostsAcl $hostsFile
    Assert-AdminOnlyWrite $hostsFile
    if ((Get-Sha256Hex ([IO.File]::ReadAllBytes($hostsFile))) -ne (Get-Sha256Hex $newBytes)) {
        throw "$hostsFile does not hold the expected content."
    }
    if ($Remove) {
        Write-Line "$hostsFile holds no blocked hostname."
    }
    else {
        Write-Line "$hostsFile holds one entry for each blocked hostname and address."
    }
}

function Invoke-MachinePhase {
    if (-not (Test-Elevated)) {
        throw 'Run the Machine phase in an elevated PowerShell.'
    }
    Assert-TrustedInvocation
    # Install only the policy bytes that the user phase checked with t3.
    $digest = Get-Sha256Hex $policyBytes
    if (-not $ValidatedPolicySha256 -or $ValidatedPolicySha256.ToLowerInvariant() -ne $digest) {
        throw 'The policy digest does not match the policy in this script. Run the User phase first and pass its digest. No file was installed.'
    }
    Assert-NoRegistryPolicy

    Initialize-AdminOnlyDirectory $policyDir
    Initialize-AdminOnlyDirectory $claudeDir
    Initialize-AdminOnlyDirectory $claudeDropInDir

    Install-AdminOnlyFile $policyFile $policyBytes
    Install-AdminOnlyFile $claudeDropInFile $claudeSettingsBytes
    Update-HostsFile $false

    Write-Line 'Done. The files on disk do not prove what a running program loaded.'
    Write-Line 'The DNS cache was not cleared. Restart the machine before the Verify phase.'
    Write-Line 'Next, without elevation, run this script with -Phase Verify.'
}

function Remove-AdminOnlyFile([string]$Target) {
    if (-not [IO.File]::Exists($Target)) {
        Write-Line "$Target does not exist."
        return
    }
    if (Test-ReparsePoint $Target) {
        throw "$Target is a link to another place. It was not deleted."
    }
    [IO.File]::Delete($Target)
    Write-Line "Deleted $Target."
}

function Invoke-RemovePhase {
    # Undo the machine phase: for example when a T3 update refuses the policy and T3 does not
    # start. The same invocation checks run first, because this phase also runs elevated.
    if (-not (Test-Elevated)) {
        throw 'Run the Remove phase in an elevated PowerShell.'
    }
    Assert-TrustedInvocation
    Remove-AdminOnlyFile $policyFile
    Remove-AdminOnlyFile $claudeDropInFile
    Update-HostsFile $true
    Write-Line 'Done. Quit and reopen T3 Code: it now runs without a managed policy.'
    Write-Line 'The user variables stay. Remove them in the user settings when you want them gone.'
}
#endregion machine-phase

#region user-phase
function Invoke-UserPhase {
    # This phase starts the t3 command, which the user can change. It must not run elevated.
    if (Test-Elevated) {
        throw 'Run the User phase in a PowerShell that is not elevated. It starts the t3 command.'
    }
    $t3 = Get-Command t3 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $t3) {
        throw 'The t3 command is not available, so the policy cannot be checked. Nothing changed.'
    }

    $work = Join-Path ([IO.Path]::GetTempPath()) ('t3code-policy-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        $candidate = Join-Path $work 'policy.json'
        [IO.File]::WriteAllBytes($candidate, $policyBytes)
        & $t3.Source policy check $candidate | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 't3 policy check rejected the policy. Nothing changed.'
        }
    }
    finally {
        Remove-Item -LiteralPath $work -Recurse -Force
    }

    # User variables. The T3 Code desktop app reads T3CODE_TELEMETRY_ENABLED and DO_NOT_TRACK.
    # DO_NOT_TRACK also turns off Claude Code telemetry and feature-flag fetching.
    $userEnvironment = [ordered]@{
        T3CODE_TELEMETRY_ENABLED            = 'false'
        DO_NOT_TRACK                         = '1'
        DISABLE_FEEDBACK_COMMAND            = '1'
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = '1'
        DISABLE_ERROR_REPORTING             = '1'
    }
    foreach ($name in $userEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $userEnvironment[$name], 'User')
        Write-Line "Set user variable $name=$($userEnvironment[$name])"
    }

    $digest = Get-Sha256Hex $policyBytes
    Write-Line "The t3 command accepted the policy. Policy SHA-256: $digest"
    Write-Line 'This digest is not a trust boundary. Follow steps 2 and 3 in the header of this script.'
    Write-Line 'Add [feedback] enabled = false to .codex\config.toml in the user profile if Codex runs here.'
}
#endregion user-phase

#region verify-phase
function Invoke-VerifyPhase {
    # This phase checks what a user process sees. It must not run elevated.
    if (Test-Elevated) {
        throw 'Run the Verify phase in a PowerShell that is not elevated.'
    }
    $failures = 0
    foreach ($blocked in $blockedHosts) {
        $state = 'blocked'
        try {
            foreach ($address in [Net.Dns]::GetHostAddresses($blocked)) {
                if ($blockedAddresses -notcontains $address.ToString()) {
                    $state = 'NOT BLOCKED, it resolves to another address'
                }
            }
        }
        catch {
            $state = 'NOT VERIFIED, the name gave no answer'
        }
        if ($state -ne 'blocked') {
            $failures++
        }
        Write-Line ($blocked + ' is ' + $state)
    }
    Write-Line 'Manual checks that this script does not make:'
    Write-Line '  1. Quit and reopen T3 Code, then run: t3 policy show'
    Write-Line '  2. Start a Claude thread in T3 Code and print DO_NOT_TRACK, DISABLE_FEEDBACK_COMMAND,'
    Write-Line '     CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY and DISABLE_ERROR_REPORTING. Each value must be 1.'
    Write-Line '  3. This check tests the address that Windows gives for each name, for IPv4 and IPv6.'
    if ($failures -gt 0) {
        throw "$failures blocked hostnames are not blocked or not verified."
    }
}
#endregion verify-phase

if ($Phase -eq 'User') {
    Invoke-UserPhase
}
elseif ($Phase -eq 'Verify') {
    Invoke-VerifyPhase
}
elseif ($Phase -eq 'Remove') {
    Invoke-RemovePhase
}
else {
    Invoke-MachinePhase
}
