# windows-home

## Purpose

The dotfiles apply on the owner's Windows machines with the same harness policy as on the Macs,
and the Macs keep exactly what they had.

## ADDED Requirements

### Requirement: Harness Configs Merge On Windows Without A Shell

On Windows, every harness `modify_` template MUST merge its policy into the live file through a
chezmoi template, with no bash, jq or yq. The merge MUST keep the keys the policy does not name and
MUST do what the macOS jq pipeline does to the keys it does name.

#### Scenario: Apply over a live harness config

- **WHEN** `chezmoi apply` runs on Windows and `~/.codex/config.toml` holds the app's own tables
- **THEN** the policy's keys are set, and the app's tables (`[windows]`, `[projects]`, its MCP
  servers) stay

#### Scenario: Live config does not parse

- **WHEN** a harness config on Windows holds text that does not parse as JSON or TOML
- **THEN** the apply stops with the parser's message, and the file stays as it was

#### Scenario: First apply

- **WHEN** a harness config does not exist yet
- **THEN** the apply writes the policy alone

### Requirement: Off Windows The Output Does Not Change

Every template this change touches MUST render, on macOS and Linux, byte for byte what it rendered
before the change.

#### Scenario: Next apply on a Mac

- **WHEN** a Mac applies the dotfiles after this change
- **THEN** no deployed file changes; only the GnuPG `run_onchange` script runs once, because its
  hash covers the `gpg-agent.conf` template source

### Requirement: Windows Starts No Shell Script

On Windows, every `run_` shell script MUST render nothing, and `.chezmoiignore` MUST skip each
target that is macOS-only, needs a Unix shell, or fails closed and is untested on Windows.

#### Scenario: Full apply on Windows

- **WHEN** `chezmoi apply` runs on Windows
- **THEN** it finishes without "%1 is not a valid Win32 application", and a second apply changes
  nothing

#### Scenario: A private value is missing

- **WHEN** the chezmoi config on Windows still holds a placeholder such as `@GITLAB_HOST@`
- **THEN** the apply stops before it writes a file and names the missing value

### Requirement: Every Harness Loads Its Config After A Windows Apply

After a Windows apply, `run_after_verify_harness_config.ps1` MUST fail the apply when Codex,
Claude Code, Grok or Muse Code rejects its config, with the harness's own message.

#### Scenario: Muse Code meets a rule it cannot enforce

- **WHEN** Muse Code on Windows refuses to start on a permission profile rule
- **THEN** the apply fails and prints Muse's refusal

### Requirement: Repository Paths Follow devRoot

Every deployed path into the folder that holds the repositories MUST come from devRoot
(`.chezmoitemplates/dev-root`): `~/Developer` on the Macs, `C:/Developer` on Windows, or the
`devRoot` value in the chezmoi config. On Windows no harness config MUST name a `~/Developer` path.

#### Scenario: Claude Code on Apex

- **WHEN** the dotfiles apply on Windows
- **THEN** Claude Code's plugin marketplaces, its extra directories and the private-folder deny
  rules name paths under `C:/Developer`, where T3 opens the projects

#### Scenario: Another layout

- **WHEN** a machine sets `devRoot` in its chezmoi config
- **THEN** those paths name that folder instead

### Requirement: The Machine's Own Settings Win On Windows

On Windows, `~/.gitconfig` MUST include `~/.config/git/provision.gitconfig` after every setting of
its own, and the jj config MUST load before `%APPDATA%\jj\config.toml`, so a machine's signing key
wins over the owner's YubiKey settings.

#### Scenario: Apex signs with the agents' key

- **WHEN** provision has written the agents' SSH signing key to its include file and to
  `%APPDATA%\jj\config.toml`
- **THEN** git and jj on Apex sign with that key, not the YubiKey's GPG key
