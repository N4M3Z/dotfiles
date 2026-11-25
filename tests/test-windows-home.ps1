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
    tailnet_host = "tailnet.example.test"

[interpreters.ps1]
    command = "powershell"
    args = ["-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]
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
                else {
                    # chezmoi's own TOML parser reads the whole output; it fails on anything that is not TOML.
                    $null = $result.Output | & chezmoi execute-template --with-stdin '{{ .chezmoi.stdin | fromToml | toJson }}' 2>&1
                    $parses = $LASTEXITCODE -eq 0
                }
            } catch { $parses = $false }
        }
        Write-Result $parses "$target renders a config that parses from an empty live file" $result.Output
    }
}

$scratch = Join-Path $work 'full'
New-Item -ItemType Directory -Path $scratch | Out-Null
# The apply ends with run_after_verify_harness_config.ps1, which starts each installed harness.
# Each one is pointed at the scratch home, so the check reads what this apply wrote, not the
# real home's configs. On a runner without the harnesses the check skips them.
$harnessHomes = [ordered]@{
    CODEX_HOME        = Join-Path $scratch '.codex'
    CLAUDE_CONFIG_DIR = Join-Path $scratch '.claude'
    GROK_HOME         = Join-Path $scratch '.grok'
    XDG_CONFIG_HOME   = Join-Path $scratch '.config'
}
$saved = @{}
foreach ($name in $harnessHomes.Keys) { $saved[$name] = [Environment]::GetEnvironmentVariable($name); [Environment]::SetEnvironmentVariable($name, $harnessHomes[$name]) }
try { $apply = Invoke-Chezmoi $scratch @('apply', '--exclude', 'externals') }
finally { foreach ($name in $harnessHomes.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) } }
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
# devRoot (.chezmoitemplates/dev-root) is C:/Developer here: no repository path stays under ~/Developer.
$claudePath = Join-Path $scratch '.claude/settings.json'
$claude = if (Test-Path -LiteralPath $claudePath) { Get-Content -LiteralPath $claudePath -Raw | ConvertFrom-Json } else { $null }
Write-Result ($claude -and $claude.extraKnownMarketplaces.runedeck.source.path -eq 'C:/Developer/runedeck/mods') "Claude Code's plugin marketplaces sit under devRoot"
Write-Result ($claude -and $claude.permissions.deny -contains 'Read(//c/Developer/**/dotfiles-private/**)') "Claude Code's home-wide denies also name devRoot (//c/Developer)"
# Claude Code exits at startup on native Windows when the sandbox it cannot run is required.
Write-Result ($claude -and $claude.sandbox.enabled -eq $false -and $claude.sandbox.failIfUnavailable -eq $false) "Claude Code's sandbox is off on Windows"
Write-Result ($claude -and -not $claude.PSObject.Properties['model'] -and -not $claude.PSObject.Properties['outputStyle']) 'Claude Code gets no model or output style the live file did not have'
$cursorPath = Join-Path $scratch '.cursor/cli-config.json'
$cursor = if (Test-Path -LiteralPath $cursorPath) { Get-Content -LiteralPath $cursorPath -Raw | ConvertFrom-Json } else { $null }
Write-Result ($cursor -and $cursor.version -eq 1) "the Cursor CLI config gets version 1 when the live file names none"
Write-Result ($cursor -and @($cursor.permissions.deny | Where-Object { $_ -like 'Read(C:/Developer/`*`*/dotfiles-private*' }).Count -gt 0) "Cursor's home-wide Read denies also name devRoot"
foreach ($target in $harnesses.Keys) {
    $file = Join-Path $scratch $target
    $text = if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }
    Write-Result ($text -and $text -notmatch '~/Developer') "$target names no ~/Developer path"
}
$gitconfig = if (Test-Path -LiteralPath (Join-Path $scratch '.gitconfig')) { Get-Content -LiteralPath (Join-Path $scratch '.gitconfig') -Raw } else { '' }
Write-Result ($gitconfig -match '(?s)\[include\]\s*path = ~/.config/git/provision.gitconfig\s*$') '.gitconfig ends with the machine include'

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
if ($failures -gt 0) { Write-Host "$failures failed"; exit 1 }
Write-Host 'all passed'
