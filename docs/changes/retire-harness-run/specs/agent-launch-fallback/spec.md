# agent-launch-fallback

## Purpose

How a coding agent starts on this machine: the vendor binary by name, `rune run` for automation, and
one fallback launcher that never shadows a vendor.

## ADDED Requirements

### Requirement: Vendor Binaries Resolve On PATH

`~/.local/bin` MUST NOT carry a `claude`, `codex`, `grok`, `agy`, or `opencode` wrapper. Each name
resolves to the vendor's own install, and the shell puts `~/.grok/bin` and the Codex app's standalone
`bin` on PATH.

#### Scenario: Claude update in progress

- **WHEN** the Claude installer is writing a new file under `~/.local/share/claude/versions` and
  `claude --version` runs
- **THEN** the installed version prints, because no wrapper reads the versions directory

#### Scenario: Grok starts by name

- **WHEN** `grok --version` runs in a login shell
- **THEN** the binary under `~/.grok/bin` answers

### Requirement: Automation Runs Through rune

By default an automated model call MUST start as `rune run <profile>`, which pins the model, sets the
access mode, and supervises the process. No file the dotfiles put on PATH MUST set `HARNESS_AUTOMATED`
policy. The one exception is `sd agent run` on a machine without rune, shaped by the next requirement.

#### Scenario: Council job calls a model

- **WHEN** a review job needs Astra
- **THEN** it runs `rune run astra@codex --clean --json` and reads one JSON object, with no wrapper
  between rune and codex

### Requirement: The Fallback Launcher Keeps Its Shape

`sd agent run <provider> [args]` MUST start the vendor binary from `HARNESS_REAL_BIN_DIR`, then PATH,
then the installer's location, add the provider's interactive sandbox flag, and in automated mode
supply the model and read-only flags a caller did not give. When it reads the Claude installer's
versions directory it MUST take the newest executable `N.N.N` file, never a download in progress.

#### Scenario: Claude download beside an installed version

- **WHEN** no `claude` is on PATH and the versions directory holds an executable `2.1.100` and a
  newer, non-executable `2.1.200`
- **THEN** `sd agent run claude` starts `2.1.100`

#### Scenario: Provider absent

- **WHEN** no binary resolves for the provider
- **THEN** the launcher exits 127 and names the provider

### Requirement: Automated Runs Author As The Model

In automated mode the fallback MUST export `JJ_USER` as `<Label> (<id>)` and `JJ_EMAIL` as
`<id>@<provider>.noreply.nexus.local`. The id is the effective model (an explicit `--model` wins) in
lowercase, every run of characters outside letters, digits, dots, and hyphens collapsed to one hyphen,
leading and trailing hyphens dropped. An id with a leading, trailing, or doubled dot is refused. The
working-copy change the run leaves behind carries the caller's identity again. The fallback MUST NOT
write a `Co-authored-by` trailer.

#### Scenario: Automated codex run commits

- **WHEN** `HARNESS_AUTOMATED=1 sd agent run codex review` changes a file in a jj repository
- **THEN** the sealed change's author is `Codex (gpt-5.5) <gpt-5.5@codex.noreply.nexus.local>`, its
  message holds no trailer, and the new working-copy change is authored by the caller

#### Scenario: Explicit model names the author

- **WHEN** `HARNESS_AUTOMATED=1 sd agent run codex --model gpt-6-astra review` changes a file
- **THEN** the sealed change's author is `Codex (gpt-6-astra) <gpt-6-astra@codex.noreply.nexus.local>`

### Requirement: Capture Never Blocks The Exit

After the harness exits, the fallback MUST hand the session to `session-sync` detached, with the
provider and the exit status, and exit with the harness status at once. When the harness succeeded
but the run's jj change could not be finalized, the launcher exits 1. The capture debt file is
session-sync's to write.

#### Scenario: Capture script missing

- **WHEN** session-sync is not executable and the harness exited 7
- **THEN** the launcher prints one warning line and exits 7 without waiting

#### Scenario: Capture script blocks

- **WHEN** session-sync sleeps for thirty seconds
- **THEN** the launcher has exited within three seconds and the capture is still running
