---
adr: "docs/decisions/DOT-0007 Vendor Binaries on PATH and rune run for Automation.md"
status: proposed
decisions:
    - "DOT-0007 Vendor Binaries on PATH and rune run for Automation"
---

# Retire the harness-run shims

## Why

Five two-line wrappers in `~/.local/bin` (`claude`, `codex`, `grok`, `agy`, `opencode`) shadow the
vendor binaries and route every start through `harness-run`, a 340-line launcher from July. It resolves
the real binary, pins a model and read-only flags for automated runs, stamps commits with a co-author
trailer, and runs session capture after exit.

Every job it does now has a better home or is wrong:

- `rune run` pins the model, sets the access mode, cleans state, and supervises automated runs. The
  shim's automated mode duplicates it, and rune has to reach under the shim with `HARNESS_REAL_BIN_DIR`
  to find grok.
- The shim resolves Claude from the newest file in the versions directory, which is the download itself
  during an auto-update. `claude` then fails with "not installed outside the wrapper directory" until
  the download finishes (2026-09-26).
- The `Co-authored-by: <Harness> / <model>` trailer is not an identity in any `authors.yaml`, so the
  attribution check of every runedeck repository refuses it. Attribution comes from the author field.
- The post-exit capture blocks the shell for minutes, holds a lock every parallel exit skips, and a
  skip counts as success.
- The same script exists twice: `harness-run` on PATH and `sd agent run` under the script dispatcher,
  which arrived as a pilot and never replaced the shim.

## What Changes

- **BREAKING** Remove the five wrappers and `harness-run` from `dot_local/bin`. Each vendor binary
  resolves on PATH as itself. `~/.grok/bin` and the Codex app's standalone `bin` join PATH.
- `rune run <profile>` is the automated launcher. Dotfiles set no `HARNESS_AUTOMATED` policy of their
  own.
- `sd agent run <provider>` stays as the fallback launcher for a machine without rune, reviewed and
  repaired: the Claude resolver skips a download in progress, automated runs author as the model
  identity through `JJ_USER` and `JJ_EMAIL` instead of a trailer, and capture is handed to session-sync
  detached so the exit never waits.
- `codex-proxy` starts `codex` directly with the proxy route.
- Record the decision in DOT-0007.

## Capabilities

### New Capabilities

- `agent-launch-fallback`: vendor binaries on PATH, `rune run` for automation, and the shape of the
  `sd agent run` fallback.

### Modified Capabilities

None.

## Impact

- `dot_local/bin/executable_{claude,codex,grok,agy,opencode,harness-run}` (removed),
  `dot_local/bin/executable_codex-proxy`, `dot_zshrc`.
- `dot_sd/agent/executable_run`, `tests/test-agent-run.sh` (renamed from `test-harness-run.sh`).
- Live: the six files leave `~/.local/bin`, and the Claude installer's own `~/.local/bin/claude` link
  returns.
- Outside this repository, two later changes: the cli drops the `HARNESS_REAL_BIN_DIR` special case
  for grok, and forge-data's `session-sync` takes the exit status from the fallback and owns the
  capture debt file.
