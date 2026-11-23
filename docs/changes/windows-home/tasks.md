# Tasks: windows-home

## 1. Implementation

- [x] 1.1 `.chezmoitemplates/harness/windows-modify`, `live` and `deep-merge`: the second-stage
  modify-template and the helpers it uses
- [x] 1.2 A Windows template per harness under `.chezmoitemplates/harness/windows/`: Claude Code,
  Codex, Cursor CLI, Gemini, Antigravity, Grok, Muse Code, OpenCode
- [x] 1.3 Shared policy templates for Claude Code, Codex, the Cursor CLI and Muse Code
- [x] 1.4 The Windows section of `.chezmoiignore`, and the Windows-only targets ignored elsewhere
- [x] 1.5 `run_` scripts render nothing on Windows; `run_after_verify_harness_config.ps1.tmpl`;
  `run_before_check_private_values` fails while rendering on Windows
- [x] 1.6 `.chezmoi.toml.tmpl`: `.ps1` scripts start with `-ExecutionPolicy Bypass` on Windows
- [x] 1.7 Windows branches in `dot_gitconfig.tmpl` and `private_gpg-agent.conf.tmpl`;
  `dot_jjconfig.toml.tmpl`
- [x] 1.8 `tests/test-windows-home.ps1` and the `windows-latest` CI job

## 2. Verification

- [x] 2.1 Every changed template renders its macOS and Linux branch byte for byte as before (each
  rendered from `main` and from this change with the Windows condition turned off, then compared)
- [x] 2.2 On Apex (chezmoi 2.74.1), each harness template renders against a copy of the live file,
  an empty file and a broken file; the broken one stops the apply
- [x] 2.3 Each harness loads the Windows output: `codex mcp list` (scratch `CODEX_HOME`),
  `claude doctor` (scratch `CLAUDE_CONFIG_DIR`), `grok inspect --json` (scratch `GROK_HOME`),
  `muse exec --provider echo` (scratch `XDG_CONFIG_HOME`), and OpenCode 2.2.7 as a project config
- [x] 2.4 A full apply into a scratch home on Apex finishes, the PowerShell harness check passes,
  and a second apply shows no difference
- [ ] 2.5 `tests/validate-templates.sh` and the other CI tests pass on Linux
- [ ] 2.6 `tests/test-windows-home.ps1` passes in CI on `windows-latest`

## 3. Record

- [x] 3.1 Record DOT-0009

## 4. Live application

- [ ] 4.1 Apex: provision's configure (git, signing, opencode) first, then `chezmoi init` with the
  secretspec store, `chezmoi diff` reviewed by the owner (the owner reads `~/.ssh/config` and
  `~/.gnupg` there), then `chezmoi apply`
- [ ] 4.2 A Mac applies the change and shows no file difference
