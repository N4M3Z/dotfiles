#Requires -Version 7
# Applies the dotfiles on Windows into a scratch home (docs/changes/windows-home).
# - Each harness modify_ template renders against an empty and a broken live file: the empty
#   one gives a config that parses, and the broken one stops the apply.
# - A full apply finishes, deploys nothing macOS-only, and a second apply changes nothing.
# The harness check that runs after the apply skips each harness that is not installed, so
# CI tests the templates only; a machine with the harnesses also tests what they accept.
# Source: https://github.com/N4M3Z/dotfiles
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { Write-Host 'skip: test-windows-home runs on Windows only'; exit 0 }

$source = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) ("dotfiles-windows-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$config = Join-Path $work 'chezmoi.toml'
@'
[data]
    privateStore = "secretspec"

[data.private]
    gitlab_host = "gitlab.example.test"
    proxy_host = "proxy.example.test"

[interpreters.ps1]
    command = "powershell"
    args = ["-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass"]
'@ | Set-Content -LiteralPath $config -Encoding utf8NoBOM

$failures = 0
function Invoke-Chezmoi([string]$Dest, [string[]]$Arguments) {
    $state = Join-Path $work ((Split-Path -Leaf $Dest) + '.boltdb')
    $output = & chezmoi --source $source --config $config --destination $Dest --persistent-state $state --no-tty @Arguments 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output | Out-String) }
}
function Write-Result([bool]$Ok, [string]$Message, [string]$Detail = '') {
    if ($Ok) { Write-Host "ok $Message" }
    else {
        Write-Host "FAIL $Message"
        if ($Detail) { $Detail.TrimEnd() -split "`r?`n" | Select-Object -First 8 | ForEach-Object { Write-Host "    $_" } }
        $script:failures++
    }
}

$harnesses = [ordered]@{
    '.claude/settings.json'                   = 'json'
    '.codex/config.toml'                      = 'toml'
    '.cursor/cli-config.json'                 = 'json'
    '.gemini/settings.json'                   = 'json'
    '.gemini/antigravity-cli/settings.json'   = 'json'
    '.grok/config.toml'                       = 'toml'
    '.config/muse/settings.json'              = 'json'
    '.config/opencode/opencode.json'          = 'json'
}
$index = 0
foreach ($target in $harnesses.Keys) {
    $index++
    foreach ($case in 'empty', 'broken') {
        $scratch = Join-Path $work "h$index-$case"
        $file = Join-Path $scratch $target
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
        if ($case -eq 'broken') { Set-Content -LiteralPath $file -Value '{"broken' -NoNewline }
        $result = Invoke-Chezmoi $scratch @('cat', $file)
        if ($case -eq 'broken') {
            Write-Result ($result.Code -ne 0) "$target stops on a live file that does not parse"
            continue
        }
        $parses = $false
        if ($result.Code -eq 0) {
            try {
                if ($harnesses[$target] -eq 'json') { $null = $result.Output | ConvertFrom-Json -ErrorAction Stop; $parses = $true }
                else { $parses = ($result.Output -match '(?m)^\s*\[') -or ($result.Output -match '(?m)^\s*[A-Za-z_]+\s*=') }
            } catch { $parses = $false }
        }
        Write-Result $parses "$target renders a config that parses from an empty live file" $result.Output
    }
}

$scratch = Join-Path $work 'full'
New-Item -ItemType Directory -Path $scratch | Out-Null
$apply = Invoke-Chezmoi $scratch @('apply', '--exclude', 'externals')
Write-Result ($apply.Code -eq 0) 'a full apply finishes' $apply.Output
$again = Invoke-Chezmoi $scratch @('diff', '--exclude', 'externals,scripts')
# chezmoi warns that the scratch config is not rendered from .chezmoi.toml.tmpl; that is no difference.
$difference = ($again.Output -split "`r?`n" | Where-Object { $_.Trim() -and $_ -notmatch '^chezmoi: warning:' }) -join "`n"
Write-Result ($again.Code -eq 0 -and -not $difference) 'a second apply changes nothing' $difference
foreach ($absent in 'Library', '.macos', '.zshrc', '.config/tmux', '.config/zed', '.config/rune', '.cursor/hooks.json', '.grok/sandbox.toml') {
    Write-Result (-not (Test-Path -LiteralPath (Join-Path $scratch $absent))) "skips $absent"
}
foreach ($present in '.jjconfig.toml', '.gitconfig', '.local/state/claude-code/api-bodies') {
    Write-Result (Test-Path -LiteralPath (Join-Path $scratch $present)) "deploys $present"
}
$gitconfig = if (Test-Path -LiteralPath (Join-Path $scratch '.gitconfig')) { Get-Content -LiteralPath (Join-Path $scratch '.gitconfig') -Raw } else { '' }
Write-Result ($gitconfig -match '(?s)\[include\]\s*path = ~/.config/git/provision.gitconfig\s*$') '.gitconfig ends with the machine include'

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
if ($failures -gt 0) { Write-Host "$failures failed"; exit 1 }
Write-Host 'all passed'
