## Purpose

Defines predictable provider routing for Codex Desktop, terminal Codex, Rune, and explicit direct-access controls.

## ADDED Requirements

### Requirement: Codex Desktop uses direct OpenAI access
The shared Codex configuration SHALL select the OpenAI provider without a selected profile.

#### Scenario: User starts Codex Desktop
- **WHEN** the user starts a local Codex Desktop task
- **THEN** Codex Desktop uses the direct OpenAI provider
- **AND** the terminal wrapper does not affect that task

### Requirement: Terminal Codex uses CLIProxyAPI by default
The managed terminal `codex` command SHALL select CLIProxyAPI unless the user selects a direct route.

#### Scenario: User starts terminal Codex normally
- **WHEN** the proxy is enabled and the required client key exists
- **THEN** the managed terminal command sends model requests through CLIProxyAPI

#### Scenario: Proxy credential is unavailable
- **WHEN** the proxy is enabled and the required client key is missing or empty
- **THEN** the terminal command stops with an actionable error
- **AND** the terminal command does not use OpenAI directly

#### Scenario: Proxy endpoint is unavailable
- **WHEN** the proxy route cannot complete a request
- **THEN** the terminal command reports the proxy failure
- **AND** the terminal command does not use OpenAI directly

### Requirement: Users can select direct Codex access
The routing controls SHALL provide one-command and persistent direct routes.

#### Scenario: User runs one direct command
- **WHEN** the user runs `noproxy codex`
- **THEN** the terminal command omits the CLIProxyAPI provider override
- **AND** the command uses the shared OpenAI provider

#### Scenario: User disables proxy launchers
- **WHEN** the user runs `cliproxy off`
- **THEN** later managed terminal Codex commands use the shared OpenAI provider

#### Scenario: User enables proxy launchers
- **WHEN** the user runs `cliproxy on` with a valid client key
- **THEN** later managed terminal Codex commands select CLIProxyAPI by default

### Requirement: Direct controls remain available without proxy credentials
The shell SHALL define `noproxy` and `cliproxy` even when the proxy environment file or client key is unavailable.

#### Scenario: Environment file is unavailable
- **WHEN** a new shell cannot read the proxy environment file
- **THEN** the user can still run `noproxy codex`, `noproxy claude`, and `cliproxy off`

### Requirement: Terminal Codex uses the standalone installation
The managed terminal wrapper SHALL execute the standalone Codex installation instead of the Codex Desktop bundle.

#### Scenario: Both Codex installations exist
- **WHEN** the standalone and Desktop-bundled Codex executables are installed
- **THEN** the managed terminal command executes the standalone Codex executable

### Requirement: Rune follows terminal Codex routing
Rune SHALL invoke the normal managed `codex` command without a separate proxy launcher.

#### Scenario: Rune starts Codex with the proxy enabled
- **WHEN** Rune starts a Codex profile through the managed command path
- **THEN** the request uses CLIProxyAPI

#### Scenario: Rune starts Codex with the proxy disabled
- **WHEN** Rune starts a Codex profile after `cliproxy off`
- **THEN** the request uses direct OpenAI access

### Requirement: Provider separation uses one Codex home
Provider selection SHALL NOT require a second `CODEX_HOME`.

#### Scenario: User reviews local usage
- **WHEN** Desktop, proxied terminal, and direct terminal sessions finish
- **THEN** their session records remain available from the shared Codex home
- **AND** `ccusage` can read that shared session source

#### Scenario: User reviews proxy usage
- **WHEN** CPA Manager reports CLIProxyAPI traffic
- **THEN** the report includes proxied terminal requests only

### Requirement: Provider credentials remain untracked
Tracked files SHALL contain only the client key variable name and its untracked source location.

#### Scenario: Terminal wrapper selects CLIProxyAPI
- **WHEN** the wrapper prepares the proxy provider
- **THEN** it passes the client key through the process environment
- **AND** it does not place the client key in command arguments or tracked files

### Requirement: Profile migration preserves unrelated profiles
The configuration merge SHALL remove known legacy routing profiles and preserve unknown named profiles.

#### Scenario: Legacy routing profiles exist
- **WHEN** the current Codex configuration contains the `direct`, `review`, or `sol` legacy routing profiles
- **THEN** the merge removes those known legacy entries and their selected default

#### Scenario: An unrelated profile exists
- **WHEN** the current Codex configuration contains another named profile
- **THEN** the merge preserves that profile

### Requirement: Direct Claude access restores account authentication
The one-command direct control SHALL remove proxy and API-key variables that override Claude.ai OAuth.

#### Scenario: User starts direct Claude Code
- **WHEN** the user runs `noproxy claude`
- **THEN** the child process does not receive `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, or `ANTHROPIC_API_KEY`
- **AND** Claude Code can use its stored Claude.ai login

### Requirement: Route status distinguishes Codex surfaces
The proxy status command SHALL report Desktop Codex and terminal Codex as separate routes.

#### Scenario: User checks routing
- **WHEN** the user runs `cliproxy status`
- **THEN** the output shows the direct Desktop route
- **AND** the output shows the current terminal route
