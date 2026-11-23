---
adr: "docs/decisions/DOT-0009 Windows Home Through Second-Stage Modify Templates.md"
status: proposed
decisions:
    - "DOT-0009 Windows Home Through Second-Stage Modify Templates"
---

# Windows Home

## Why

The owner's Windows workstation, Apex, runs the same harnesses as the Macs: Claude Code, Codex,
Grok Build, Cursor, Gemini and Antigravity, Muse Code and OpenCode, most of them under T3 Code. Their
policy (permissions, sandbox, auto-review prose, telemetry) lives in this repository, and none of it
reaches Apex. A `chezmoi apply` there fails on the first harness file, because every harness
`modify_` template renders a `#!/bin/bash` script that pipes the live file through jq and yq, and
Windows cannot start it ("%1 is not a valid Win32 application"). The macOS-only parts (Library,
`.macos`, zsh, tmux, Ghostty, Zed) would deploy too, and seven `run_` scripts render a shell header
that Windows tries to execute.

## What Changes

- Each harness `modify_` template keeps its shell script for macOS and Linux and, on Windows,
  prints a second-stage modify-template instead (DOT-0009). chezmoi runs that a second time with
  the live file in `.chezmoi.stdin`, and the template under `.chezmoitemplates/harness/windows/`
  does the jq merge step for step. Shared helpers parse the live JSON or TOML (`harness/live`) and
  reproduce jq's `*` (`harness/deep-merge`). Windows needs no bash, jq or yq.
- The policy computations that both branches need move into `.chezmoitemplates/harness/`:
  `claude-settings.json`, `codex-policy`, `cursor-cli-policy` and `muse-policy`.
- Off Windows, every changed template renders byte for byte what it rendered before.
- On Windows only:
  - Codex drops filesystem rules that start with `/`, which it refuses there.
  - Muse spells home paths as `~/`, drops Unix socket rules and the `:workspace_roots` deny rules,
    which it cannot enforce there and would refuse to start on, and leaves its managed hooks off.
  - Claude Code writes raw API bodies to `~/.local/state/claude-code/api-bodies`, and takes
    mkcert's Windows root only when it exists.
- `.chezmoitemplates/dev-root` names the folder that holds the repositories: `~/Developer` on
  the Macs, `C:/Developer` on Windows, where it sits outside the home folder. A `devRoot` key in
  the chezmoi config overrides it. Claude Code's plugin marketplaces, the private SSH host links
  and Vale's style links use it. On Windows the harness merges move `~/Developer` and the private
  folder there (`harness/windows/paths`), so the rules match the paths the harnesses open.
- `.chezmoiignore` gets a Windows section, listed under Impact.
- Every `run_` shell script renders nothing on Windows. `run_after_verify_harness_config.ps1.tmpl`
  is the Windows twin of the harness check. `run_before_check_private_values` stops a Windows
  apply while rendering, because no shell script can run there.
- `.chezmoi.toml.tmpl` makes chezmoi start `.ps1` scripts with `-ExecutionPolicy Bypass` on Windows.
- `dot_gitconfig.tmpl` on Windows drops the macOS signing wrapper and the git-ai trace2 socket, and
  includes `~/.config/git/provision.gitconfig` last, so a machine's own git settings win.
- `dot_jjconfig.toml.tmpl` puts the jj config at `~/.jjconfig.toml` on Windows, where jj reads it
  before `%APPDATA%\jj\config.toml`.
- `private_gpg-agent.conf.tmpl` leaves out `pinentry-program` on Windows.
- `tests/test-windows-home.ps1` and a `windows-latest` CI job apply the source on Windows.

## Capabilities

### New Capabilities

- `windows-home`: the dotfiles apply on Windows, the harnesses load what they write, and the macOS
  output does not change.

### Modified Capabilities

None.

## Impact

- New: `.chezmoitemplates/harness/**`, `run_after_verify_harness_config.ps1.tmpl`,
  `dot_jjconfig.toml.tmpl`, `dot_local/state/claude-code/api-bodies/.keep`,
  `tests/test-windows-home.ps1`, DOT-0009.
- Changed: the nine harness `modify_` templates, `.chezmoiignore`, `.chezmoi.toml.tmpl`,
  `dot_gitconfig.tmpl`, `private_gpg-agent.conf.tmpl`, eight `run_` scripts, the CI workflow,
  README.
- Skipped on Windows by `.chezmoiignore`:
  - macOS-only: Library, `.macos`, zsh, tmux, Ghostty, Zed, cmux, OpenLogi and the forge project.
  - `.local/bin` scripts that need macOS.
  - rune's config, because rune does not build on Windows.
  - `.config/jj`, which jj does not read on Windows.
  - Untested and failing closed: Cursor's dcg hook and sandbox, Grok's sandbox profiles.
  - Vale.
  - Links whose targets the machine lacks: `~/Developer`, `~/Atlas`, `.claude/rules`, the private
    SSH host files.
- Macs: no deployed file changes. `run_onchange_after_gnupg.sh` hashes the `gpg-agent.conf`
  template, which changed, so it runs once more on each Mac. It writes the same default again and
  restarts gpg-agent, which then asks for the YubiKey PIN once.
- Apex: the companion provision change merges its OpenCode manifest instead of copying it, and
  moves its git settings to the included file.
- Follow-ups:
  - Cursor's dcg hook and Muse's managed hooks on Windows, after a hook test.
  - Grok sandbox profiles on Windows.
  - Vale, gitui, tuicr and codebook, which read `%APPDATA%` or `%LOCALAPPDATA%`.
  - The macOS-worded `automode.json` prose.
  - Moving the Macs' raw API bodies to the new location with provision's telemetry pipeline.
