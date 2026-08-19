## Why

A global proxy provider makes Codex Desktop lose OpenAI account features. Separate entry-point routing keeps Desktop direct and meters terminal traffic.

## What Changes

- Adopt [DOT-0003](../../../docs/decisions/DOT-0003%20Separate%20Codex%20Desktop%20and%20CLI%20Provider%20Routing.md) for the provider boundary.
- Keep `openai` as the shared Codex configuration provider.
- Keep `cliproxyapi` as a selectable provider that reads `CLIPROXY_API_KEY_CODEX` from the environment.
- Make the managed terminal `codex` wrapper select `cliproxyapi` by default.
- Make `noproxy codex` and `cliproxy off` select the direct OpenAI route.
- Make proxy failures stop the terminal command instead of silently selecting OpenAI.
- Make terminal Codex prefer the standalone installation over the Codex Desktop bundle.
- Make Rune call the normal `codex` wrapper and remove the separate `codex-proxy` launcher.
- Preserve one `CODEX_HOME` for sessions, usage reports, and shared configuration.
- Preserve named Codex profiles while removing any persistent default profile selection.
- Keep Claude proxy routing as the default and keep `noproxy claude` as the direct OAuth route.
- Add the OpenSpec planning tree to `.chezmoiignore` before any Chezmoi dry run.
- Do not run `chezmoi apply`. The user applies the reviewed source later.

## Capabilities

### New Capabilities

- `codex-provider-routing`: Defines provider selection, bypass controls, binary selection, failure behavior, and usage visibility for each Codex entry point.

### Modified Capabilities

None.

## Impact

The change affects Codex policy data, the Codex wrapper, the shared harness runner, Rune, and CLIProxyAPI shell controls. It removes rejected draft launchers.

The change adds OpenSpec planning files and one ForgeADR. Existing Context7, permission, and unrelated dotfile changes remain outside this scope.
