## Purpose

Defines provider routing by launch surface while preserving direct vendor features and explicit control over terminal request routing.

## ADDED Requirements

### Requirement: Desktop applications use direct vendor services

The configuration MUST keep Codex Desktop on OpenAI authentication and Claude Desktop on Anthropic authentication.

The configuration MUST NOT enable third-party inference for either desktop application.

#### Scenario: Codex Desktop starts

- **WHEN** the user starts Codex Desktop
- **THEN** the application uses the OpenAI provider without a CLIProxyAPI override
- **THEN** OpenAI cloud-agent and remote-access features remain available when the account permits them

#### Scenario: Claude Desktop starts

- **WHEN** the user starts Claude Desktop
- **THEN** the application uses its Anthropic account without third-party inference
- **THEN** Anthropic-hosted desktop features remain available when the account permits them

### Requirement: Managed terminal harnesses use CLIProxyAPI by default

The managed terminal `codex` and `claude` launchers MUST select CLIProxyAPI unless the user selects a direct route.

Rune launches for these harnesses MUST use the same route contract.

#### Scenario: Terminal Codex starts with proxy routing enabled

- **WHEN** the user runs managed terminal `codex`
- **THEN** the launcher selects the configured CLIProxyAPI model provider
- **THEN** the launcher passes all user arguments to Codex

#### Scenario: Terminal Claude starts with proxy routing enabled

- **WHEN** the user runs managed terminal `claude`
- **THEN** the launcher supplies the CLIProxyAPI endpoint and client credential to Claude Code
- **THEN** the launcher passes all user arguments to Claude Code

#### Scenario: Rune starts a managed harness

- **WHEN** Rune launches a Codex or Claude profile
- **THEN** the launch uses the same enabled or disabled proxy state as the managed terminal launcher

### Requirement: Proxy routing stays local to each terminal process

The proxy setup MUST inject provider routing when a managed terminal launcher starts.

Shell startup MUST NOT export vendor endpoint or vendor authentication overrides for unrelated processes.

#### Scenario: A fresh shell starts

- **WHEN** the shell loads the proxy controls
- **THEN** vendor endpoint and authentication overrides remain absent from the ambient shell environment
- **THEN** managed terminal launchers can still select CLIProxyAPI

### Requirement: Direct and proxied routes share harness state

Route selection MUST preserve each harness configuration home and local session-storage location.

The Codex configuration merge MUST preserve unrelated profiles and application-managed settings.

#### Scenario: Codex changes routes

- **WHEN** Codex changes between direct and proxied terminal routes
- **THEN** both routes use the same `CODEX_HOME`
- **THEN** existing Codex profiles and application settings remain present

#### Scenario: Claude changes routes

- **WHEN** Claude changes between direct and proxied terminal routes
- **THEN** both routes use the same Claude configuration and local session home

### Requirement: One command can bypass the proxy

The `noproxy` command MUST select direct vendor routing for one child process.

It MUST remove credential and provider overrides that outrank the required vendor login.

It MUST NOT change the saved proxy state for later commands.

#### Scenario: One Claude command uses direct authentication

- **WHEN** the user runs `noproxy claude` while proxy routing is enabled
- **THEN** that process uses the saved direct vendor login
- **THEN** a later plain `claude` command uses CLIProxyAPI again

#### Scenario: One Codex command uses direct authentication

- **WHEN** the user runs `noproxy codex` while proxy routing is enabled
- **THEN** that process starts without the CLIProxyAPI provider override
- **THEN** a later plain `codex` command uses CLIProxyAPI again

### Requirement: The user can persistently disable terminal proxy routing

The `cliproxy off` command MUST make managed terminal harnesses use their direct routes.

The `cliproxy on` command MUST restore proxy-default routing for later managed terminal processes.

#### Scenario: Proxy routing is disabled

- **WHEN** the user runs `cliproxy off`
- **THEN** later managed Codex and Claude commands use direct vendor routes
- **THEN** Rune follows the same direct route state

#### Scenario: Proxy routing is enabled again

- **WHEN** the user runs `cliproxy on`
- **THEN** later managed Codex and Claude commands use CLIProxyAPI
- **THEN** Rune follows the same proxy route state

### Requirement: Proxy failures do not change routes

An enabled proxied launcher MUST fail when its required credential is unavailable.

A failed CLIProxyAPI request MUST NOT retry through the direct vendor service.

#### Scenario: A proxy credential is unavailable

- **WHEN** the user starts a managed proxied harness without its required client credential
- **THEN** the launcher exits with an actionable error
- **THEN** the launcher does not start a direct vendor request

#### Scenario: CLIProxyAPI is unavailable

- **WHEN** a proxied harness cannot reach CLIProxyAPI
- **THEN** the request fails through the selected proxy route
- **THEN** the harness does not change to a vendor endpoint

### Requirement: Direct Claude supports Remote Control

The direct Claude route MUST allow full-scope Claude.ai authentication to remain active.

The route MUST remove proxy, API-key, setup-token, cloud-provider, profile, and feature-evaluation overrides that block Remote Control.

#### Scenario: Remote Control starts in server mode

- **WHEN** the user runs `noproxy claude remote-control` from a trusted project
- **THEN** Claude uses a full-scope Claude.ai subscription login
- **THEN** Claude displays a Remote Control session URL
- **THEN** the session is available through a supported Claude Remote Control client

#### Scenario: Remote Control starts in interactive mode

- **WHEN** the user runs `noproxy claude --remote-control` or `noproxy claude --rc`
- **THEN** Claude starts an interactive direct session with Remote Control active
- **THEN** messages can pass between the local process and a supported remote client

### Requirement: Direct Claude supports Claude in Chrome

The direct Claude route MUST preserve Claude in Chrome when Anthropic account and extension requirements are satisfied.

#### Scenario: Chrome integration starts

- **WHEN** the user runs `noproxy claude --chrome` with a compatible extension and browser
- **THEN** Claude uses the full-scope Claude.ai subscription login
- **THEN** `/chrome` reports `Status: Enabled` and `Extension: Installed`

#### Scenario: Chrome integration reads a page

- **WHEN** Chrome integration is enabled in a direct Claude session
- **THEN** Claude can open and inspect a harmless test page after required user approval

### Requirement: Route status is explicit

The `cliproxy status` command MUST report the route for each managed terminal harness and desktop application.

It MUST report proxy health without printing any credential.

#### Scenario: Status is requested

- **WHEN** the user runs `cliproxy status`
- **THEN** the output distinguishes terminal Codex, terminal Claude, Codex Desktop, and Claude Desktop
- **THEN** the output shows the persistent proxy state and CLIProxyAPI health
- **THEN** the output contains no credential value

### Requirement: Credentials remain untracked and absent from arguments

Tracked files MUST contain credential variable names only.

Launchers MUST pass proxy credentials through the environment and MUST NOT place them in process arguments.

#### Scenario: Managed sources are inspected

- **WHEN** a reviewer inspects the Chezmoi sources and rendered command arguments
- **THEN** no real client credential is present
- **THEN** the proxy provider refers to a credential environment variable

### Requirement: Accounting follows the selected route

Proxied terminal requests MUST remain visible to CLIProxyAPI accounting.

Direct requests MUST remain outside CLIProxyAPI accounting.

Route selection MUST NOT relocate local harness session data.

#### Scenario: A proxied terminal request completes

- **WHEN** a terminal harness completes a request through CLIProxyAPI
- **THEN** CPA Manager can account for that proxy request
- **THEN** the harness keeps any local session record in its standard session home

#### Scenario: A direct request completes

- **WHEN** a desktop application or direct terminal harness completes a vendor request
- **THEN** the system does not claim that request appears in CPA Manager
- **THEN** local usage readers retain their existing coverage of vendor-written session data
