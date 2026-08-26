## Why

Provider routing now changes application behavior as well as request transport. Desktop proxy routing removes vendor features that require direct authentication.

The configuration must separate terminal routing from application routing. This separation keeps terminal accounting without disabling cloud, Remote Control, or Chrome features.

## What Changes

- Keep Codex Desktop and Claude Desktop on direct vendor authentication.
- **BREAKING** Route managed terminal `codex` and `claude` commands through CLIProxyAPI by default.
- Add one-process and persistent direct routes for vendor-only terminal features.
- Move proxy settings from shell startup into the managed terminal launchers.
- Fail proxied commands when their proxy configuration or credentials are unavailable.
- Keep one configuration home for each harness across direct and proxied routes.
- Define acceptance checks for Codex cloud features, Claude Remote Control, and Claude in Chrome.
- Record the routing decision in [DOT-0003 Provider Proxy Setup](../../../docs/decisions/DOT-0003%20Provider%20Proxy%20Setup.md).
- Record the direct-feature decision in [DOT-0004 Preserve Vendor Features With Direct Sessions](../../../docs/decisions/DOT-0004%20Preserve%20Vendor%20Features%20With%20Direct%20Sessions.md).

## Capabilities

### New Capabilities

- `provider-proxy-setup`: Defines route selection, explicit bypasses, failure behavior, feature access, and route reporting.

### Modified Capabilities

None.

## Impact

The change affects Chezmoi sources for terminal wrappers, Codex policy, Rune launchers, proxy controls, tests, and ignored paths.

CLIProxyAPI and CPA Manager observe only proxied terminal requests. Direct vendor requests remain outside those reports.

Local usage tools keep the existing session homes. Their coverage still depends on which sessions each vendor stores locally.
