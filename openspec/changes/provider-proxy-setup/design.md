## Context

See [proposal.md](proposal.md) for the reason for this change. The current shell startup exports Anthropic proxy settings into every child process.

Codex already has one shared configuration file. A provider definition exists, but terminal Codex does not select it by default.

Claude Desktop and Codex Desktop need direct vendor authentication. Terminal sessions need CLIProxyAPI routing for accounting and multi-account routing.

The related decisions are:

- [DOT-0003 Provider Proxy Setup](../../../docs/decisions/DOT-0003%20Provider%20Proxy%20Setup.md)
- [DOT-0004 Preserve Vendor Features With Direct Sessions](../../../docs/decisions/DOT-0004%20Preserve%20Vendor%20Features%20With%20Direct%20Sessions.md)

The design uses this route matrix:

| Surface | Normal route | Explicit direct route |
| --- | --- | --- |
| Codex Desktop | OpenAI | Always direct |
| Claude Desktop | Anthropic | Always direct |
| Terminal Codex | CLIProxyAPI | `noproxy codex` or `cliproxy off` |
| Terminal Claude | CLIProxyAPI | `noproxy claude` or `cliproxy off` |
| Rune Codex and Claude | Managed terminal wrappers | `noproxy` or `cliproxy off` |

## Goals / Non-Goals

**Goals:**

- Select provider routing at the process launcher.
- Keep desktop applications on vendor authentication.
- Make terminal proxy routing the default.
- Keep one configuration and session home for each harness.
- Preserve Remote Control and Chrome through an explicit direct Claude route.
- Keep proxy failures visible and route changes intentional.
- Preserve local session capture and proxy accounting within their actual coverage.

**Non-Goals:**

- Configure third-party inference in either desktop application.
- Make direct vendor requests appear in CPA Manager.
- Promise that a local usage reader covers sessions the vendor does not store locally.
- Create a second `CODEX_HOME` or Claude configuration home.
- Change CLIProxyAPI account-selection policy.
- Automate vendor login, extension installation, organization policy, or `chezmoi apply`.

## Decisions

### Route by launch surface

Desktop applications remain direct. Managed terminal wrappers select CLIProxyAPI for each child process.

This boundary matches the feature boundary. Desktop applications keep their vendor sessions, while terminal requests remain visible to the proxy.

The `codex` and `claude` wrapper scripts own route selection. `harness-run` keeps session capture, automation policy, and process attribution.

The real-binary resolver prefers the owned standalone installation before its sanitized `PATH` fallback. This order prevents terminal Codex from selecting the desktop application bundle.

Alternatives included global environment variables and separate configuration homes. Global variables affect unrelated child processes. Separate homes split profiles and local usage data.

### Keep OpenAI as the shared Codex default

The managed Codex policy keeps `model_provider = "openai"`. Codex Desktop therefore uses its normal OpenAI authentication.

The same policy defines `model_providers.cliproxyapi`. That provider uses the Responses wire API and the local CLIProxyAPI endpoint.

The provider reads `CLIPROXY_API_KEY_CODEX` through `env_key`. It does not run an authentication command or parse `~/.env` from TOML.

The terminal `codex` wrapper adds this process override:

```text
--config 'model_provider="cliproxyapi"'
```

The wrapper does not change `CODEX_HOME`. The configuration merge also preserves existing `profile`, `profiles`, and unknown application fields.

Alternatives included a second Codex home and a dynamic authentication command. Both alternatives add state or logic without improving routing.

### Inject Claude proxy settings only in the Claude child process

Shell startup loads only the required `CLIPROXY_*` values. It does not export `ANTHROPIC_BASE_URL` or `ANTHROPIC_AUTH_TOKEN`.

When proxy routing is active, the `claude` wrapper validates `CLIPROXY_API_KEY`. It then supplies these values only to its child process:

```text
ANTHROPIC_BASE_URL=http://127.0.0.1:8317
ANTHROPIC_AUTH_TOKEN=${CLIPROXY_API_KEY}
```

The token remains in the child environment. It never enters a tracked file or process argument.

When the key is missing, the wrapper exits before it starts Claude Code. An unavailable endpoint fails as a proxy request.

Alternatives included permanent shell exports and Claude Desktop third-party inference. Both alternatives remove vendor-only features from affected surfaces.

### Use one-shot and persistent direct controls

`noproxy` sets `CLIPROXY_BYPASS=1` for one process. The managed wrappers then omit their proxy overrides.

For Claude, `noproxy` also removes sources that can outrank or disable the saved `/login` credential:

```text
ANTHROPIC_BASE_URL
ANTHROPIC_AUTH_TOKEN
ANTHROPIC_API_KEY
CLAUDE_CODE_OAUTH_TOKEN
CLAUDE_CODE_USE_BEDROCK
CLAUDE_CODE_USE_VERTEX
CLAUDE_CODE_USE_FOUNDRY
ANTHROPIC_PROFILE
ANTHROPIC_FEDERATION_RULE_ID
ANTHROPIC_ORGANIZATION_ID
DISABLE_TELEMETRY
DO_NOT_TRACK
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
DISABLE_GROWTHBOOK
```

This cleanup affects only the child process. The saved Claude.ai login remains in the vendor credential store.

The managed Claude settings do not define `apiKeyHelper`. A user-selected Claude apps gateway can still outrank `/login`.

`cliproxy off` creates the existing persistent off flag. Managed wrappers sanitize and use direct routes while that flag exists.

`cliproxy on` removes the flag. It does not export vendor routing variables into the current shell.

The one-shot control supports feature commands without changing later terminal routing. The persistent control supports a direct work period.

### Keep Rune on the managed wrapper contract

Rune uses `codex` instead of `codex-proxy`. Its Claude profiles stop setting proxy endpoints and client credentials.

Rune retains profile model identifiers and other model-specific values. The managed wrappers provide the transport route.

Some proxy-specific model identifiers are invalid on a direct vendor route. Direct Rune checks must use a vendor-compatible profile.

The existing `codex-proxy` launcher remains as a compatibility command. Rune no longer depends on it.

### Report routes and accounting boundaries

`cliproxy status` reports separate rows for terminal Codex, terminal Claude, Codex Desktop, Claude Desktop, and Grok.

The report shows the saved on or off state and probes the local endpoint. It never prints a key.

CPA Manager receives only requests that pass through CLIProxyAPI. Direct desktop and terminal requests do not enter its records.

The route change does not move local session files. Tools such as `ccusage` retain their current coverage of vendor-written local sessions.

### Verify vendor-only Claude features after application

Automated tests verify route selection before live application. They use fake vendor binaries and capture child arguments and environment names.

Remote Control requires a full-scope `/login`, an eligible account, workspace trust, and applicable organization approval.

The manual test starts `noproxy claude --remote-control`. It checks the session URL and a message round trip through `claude.ai/code` or mobile.

The server-mode test uses `noproxy claude remote-control`. It checks the URL and connection state.

Claude in Chrome requires a supported browser and extension version 1.0.36 or later. The manual test starts `noproxy claude --chrome`.

The test checks `/chrome` for `Status: Enabled` and `Extension: Installed`. It then reads a harmless test page.

Claude Desktop remains direct. A separate manual check confirms its Claude in Chrome connector and its available Remote Control integration.

The configuration cannot satisfy account, policy, or extension prerequisites. Failed prerequisite checks stop verification with a specific instruction.

## Risks / Trade-offs

- [Risk] A direct Claude process can still use an active Claude apps gateway. → Check `/status` before feature tests.
- [Risk] Child cleanup removes privacy blockers for that direct process. → Limit cleanup to the explicit direct process.
- [Risk] Existing shells can retain old proxy exports after Chezmoi changes. → Start a new shell or remove the old variables before testing.
- [Risk] A shared Codex provider definition can remain visible while inactive. → Keep `openai` as the shared default and verify the application route.
- [Risk] Proxy-specific Rune models can fail during direct mode. → Use a vendor-compatible Rune profile for direct checks.
- [Risk] CLIProxyAPI downtime blocks default terminal work. → Keep the failure explicit and use an intentional direct control.
- [Risk] Vendor updates can change feature prerequisites. → Keep post-application checks tied to current vendor status output.

## Migration Plan

1. Add `openspec` to `.chezmoiignore` before any Chezmoi render check.
2. Simplify the Codex provider credential setting to `env_key`.
3. Preserve unrelated Codex profiles during the managed configuration merge.
4. Add route selection to the managed Codex and Claude wrappers.
5. Remove ambient Anthropic proxy exports from shell startup.
6. Expand `noproxy`, `cliproxy on`, `cliproxy off`, and route status.
7. Move Rune transport routing onto the managed wrappers.
8. Add fake-binary tests for arguments, environments, failure behavior, and shared state.
9. Render the Chezmoi diff and run syntax checks without applying it.
10. Let the user review and run `chezmoi apply`.
11. Run direct Codex, Remote Control, Chrome, Desktop, accounting, and local-session checks.

If validation fails before application, restore the source changes. If live validation fails, use `cliproxy off` for terminal access.

The user can then revert the reviewed source change and apply that rollback separately.
