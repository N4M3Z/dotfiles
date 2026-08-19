## Context

See [proposal.md](proposal.md) for the motivation. The shared Codex configuration already supports named model providers and command-line overrides.

Codex Desktop executes its bundled Codex binary. The terminal wrapper passes commands through `harness-run`. That runner currently finds the Desktop bundle before the standalone installation.

The rejected draft added a separate `codex-proxy` command and made Rune call it. The draft also deleted all named Codex profiles during each configuration merge.

## Goals / Non-Goals

**Goals:**

- Select the provider from the launcher without a second Codex home.
- Keep direct access explicit and available when proxy credentials are missing.
- Keep normal proxy failures visible.
- Preserve unrelated profiles and worktree changes.
- Keep provider credentials outside tracked files and process arguments.

**Non-Goals:**

- Change CLIProxyAPI account routing or CPA Manager behavior.
- Change Codex Desktop cloud implementation.
- Change the existing Context7 cache or Codex permission work.
- Apply the rendered Chezmoi configuration to the home directory.

## Decisions

### Keep OpenAI as the shared configuration default

The rendered `~/.codex/config.toml` selects `openai`. It also defines `cliproxyapi` as an available provider with `wire_api = "responses"`.

The provider uses `env_key = "CLIPROXY_API_KEY_CODEX"`. This choice replaces the draft command-based authentication helper.

Alternative: select CLIProxyAPI in the shared configuration. This option also routes Desktop and disables direct account features.

### Select CLIProxyAPI in the terminal wrapper

The managed `codex` wrapper checks direct controls before it selects a provider. `CLIPROXY_BYPASS=1` or the proxy off flag starts `harness-run codex` without an override.

The normal route obtains `CLIPROXY_API_KEY_CODEX` from the current environment. If necessary, it reads only that named value from `~/.env`.

The wrapper exports the value and prepends `--config 'model_provider="cliproxyapi"'`. It never includes the key value in the argument list.

The wrapper reports a missing or empty key before launch. It names `noproxy codex` and `cliproxy off` as direct alternatives.

Alternative: use a separate `codex-proxy` command. That option reverses the requested default and duplicates launcher policy.

### Prefer the standalone Codex binary

The wrapper identifies the standalone Codex binary for `harness-run`. This selection prevents terminal behavior from changing with the Desktop application bundle.

The change must not reorder binary selection for Claude, Grok, or other harnesses.

Alternative: keep the current path search. That option can select the older Desktop-bundled CLI for terminal commands.

### Use one bypass contract

`noproxy` sets `CLIPROXY_BYPASS=1` for one child process. It removes Anthropic proxy and API-key variables from that child.

`cliproxy off` creates the existing off flag and removes proxy variables from the current shell. `cliproxy on` removes the flag only after it finds the required client key.

The shell defines both controls before any credential check. Direct access therefore remains available without `~/.env`.

Alternative: edit `~/.codex/config.toml` from the shell function. That option changes shared Desktop state and makes source convergence harder.

### Make Rune use the normal command

Rune resolves `codex` through the managed path. Rune keeps its model and reasoning overrides but removes the `codex-proxy` binary override.

Alternative: keep a Rune-only proxy launcher. That option creates another routing path and different failure behavior.

### Limit profile migration to known legacy profiles

The configuration merge removes a selected `direct`, `review`, or `sol` profile. It removes only those named profile tables and deletes an empty profile container.

The merge preserves every unknown profile. This approach replaces the draft `del(.profile, .profiles)` expression.

Alternative: delete all profile data during each Chezmoi run. That option destroys future user profiles that do not affect routing.

### Keep one session and usage store

All routes keep the default `CODEX_HOME`. `ccusage` therefore reads one session source.

CPA Manager observes only requests that pass through CLIProxyAPI. Direct Desktop and bypass requests remain outside its report.

The route belongs to the current launcher. Resuming one session from another surface can therefore change the provider route.

Alternative: use separate Codex homes. That option isolates providers but divides sessions, authentication, and usage data.

### Keep planning files out of the home deployment

The apply phase adds `openspec` to `.chezmoiignore` before any Chezmoi dry run. The existing `docs` ignore entry already covers the ForgeADR.

The user runs `chezmoi apply` only after review. The apply phase stops after source verification and a rendered dry run.

## Risks / Trade-offs

- [A direct binary invocation bypasses the wrapper] → Document the managed `codex` command as the supported terminal entry point.
- [A resumed session can change providers across surfaces] → Report routes by entry point and keep one shared session history.
- [A stale off flag keeps terminal Codex direct] → Make `cliproxy status` show the active terminal route.
- [A proxy outage blocks normal terminal work] → Report the failure and provide explicit direct commands.
- [An environment file can contain duplicate keys] → Read the first exact key and reject an empty value.

## Migration Plan

1. Ignore the OpenSpec planning tree in Chezmoi.
2. Render the shared Codex configuration with OpenAI as the default.
3. Replace the rejected launcher with terminal-wrapper routing.
4. Update shell controls, Rune, binary selection, and targeted profile migration.
5. Validate syntax and inspect a Chezmoi dry run.
6. Stop for user review without applying the rendered configuration.

Rollback restores the previous wrapper and Rune source. It also removes the terminal provider override while the shared OpenAI default remains safe.
