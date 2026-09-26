# Tasks: retire-harness-run

## 1. PATH

- [x] 1.1 Remove `dot_local/bin/executable_{claude,codex,grok,agy,opencode,harness-run}`
- [x] 1.2 `dot_local/bin/executable_codex-proxy` starts `codex` from PATH with the proxy route
- [x] 1.3 `dot_zshrc` puts `~/.grok/bin` and the Codex standalone `bin` on PATH and drops the shim
  comment. `cliproxy.zsh` exports grok's proxy route, which the launcher used to inject

## 2. Fallback launcher

- [x] 2.1 `dot_sd/agent/executable_run`: the Claude resolver takes the newest executable version file
- [x] 2.2 Automated mode exports `JJ_USER` and `JJ_EMAIL` as the model identity and writes no trailer
- [x] 2.3 Capture is handed to session-sync detached with `--status`, and the debt functions leave the
  script
- [x] 2.4 `tests/test-agent-run.sh` (renamed) covers the resolver, the author identity, and the
  detached capture (31 assertions)

## 3. Review and record

- [x] 3.1 Adversarial pass by Fable 5.1 and Astra on the spec and the launcher, findings dispositioned
  in `design.md`
- [x] 3.2 Record DOT-0007

## 4. Live application

- [x] 4.1 The six files left `~/.local/bin` (trashed), the Claude installer link `~/.local/bin/claude`
  is back, and `claude`, `codex`, `grok`, `agy`, `opencode` resolve by name in a login shell
  (2026-09-26)

## 5. Later changes elsewhere

- [ ] 5.1 cli: drop the `HARNESS_REAL_BIN_DIR` special case for grok in `src/cli/surface/mod.rs`
- [ ] 5.2 forge-data: `session-sync --provider <p> --status <n>` writes the capture debt file under
  `~/.local/state/rune/capture-debt/`. Until then a failed capture from the fallback leaves no debt
  file. The fallback is not the default launcher, so nothing on this machine hits that gap today
