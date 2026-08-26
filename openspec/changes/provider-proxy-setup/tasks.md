## 1. Protect Planning and Existing Work

- [ ] 1.1 Add `openspec` to `.chezmoiignore`. Verify Chezmoi excludes the planning tree from rendered output.
- [ ] 1.2 Record the existing worktree state before implementation. Verify later diffs preserve unrelated staged, unstaged, and untracked work.
- [ ] 1.3 Limit implementation edits to the approved provider-routing files and tests. Verify the final path list against this change.

## 2. Configure Shared Codex Routing

- [ ] 2.1 Keep `openai` as the managed Codex default. Verify the rendered top-level provider remains `openai`.
- [ ] 2.2 Define CLIProxyAPI with `env_key = "CLIPROXY_API_KEY_CODEX"`. Verify no provider authentication command remains.
- [ ] 2.3 Preserve `profile`, `profiles`, and unknown Codex fields during policy merging. Verify this behavior with a merge fixture.
- [ ] 2.4 Keep one `CODEX_HOME` for both routes. Verify fake direct and proxied launches receive the same home.

## 3. Route Managed Terminal Launchers

- [ ] 3.1 Make terminal `codex` select CLIProxyAPI by default. Verify a fake binary captures the provider override and user arguments.
- [ ] 3.2 Make terminal `codex` omit the override during bypass or off state. Verify both direct cases with a fake binary.
- [ ] 3.3 Make terminal `claude` inject proxy endpoint and token only into its child. Verify the parent environment stays unchanged.
- [ ] 3.4 Sanitize direct Claude authentication and feature blockers. Verify a fake direct child receives none of the documented overrides.
- [ ] 3.5 Reject missing proxy credentials before launching either harness. Verify the fake vendor binaries remain uncalled.
- [ ] 3.6 Prefer owned standalone binaries before sanitized `PATH` results. Verify terminal Codex does not select the desktop bundle.
- [ ] 3.7 Retain `codex-proxy` as a compatible explicit launcher. Verify it follows the saved off state.

## 4. Unify Proxy Controls and Rune

- [ ] 4.1 Remove ambient Anthropic route exports from shell startup. Verify a clean shell has no managed vendor override.
- [ ] 4.2 Expand `noproxy` for one direct child process. Verify the saved proxy state remains unchanged afterward.
- [ ] 4.3 Keep `cliproxy off` and `cliproxy on` as persistent controls. Verify new launcher processes follow the saved state.
- [ ] 4.4 Report terminal, desktop, Grok, and proxy-health rows. Verify status output contains no credential values.
- [ ] 4.5 Move Rune Codex transport to the managed `codex` wrapper. Verify Rune no longer depends on `codex-proxy`.
- [ ] 4.6 Remove proxy endpoint and token fields from Rune Claude profiles. Verify the wrapper supplies their transport route.
- [ ] 4.7 Test Rune direct mode with a vendor-compatible model profile. Verify proxy-specific profiles remain documented as incompatible.

## 5. Validate Sources Before Installation

- [ ] 5.1 Add fake-binary route tests for arguments, environments, failures, and shared homes. Verify the complete test suite passes.
- [ ] 5.2 Run Bash, Zsh, JSON, YAML, and TOML syntax checks. Verify every changed source parses successfully.
- [ ] 5.3 Search changed sources for secret literals and obsolete authentication commands. Verify only credential variable names remain.
- [ ] 5.4 Validate the OpenSpec change and both ForgeADRs. Verify strict OpenSpec and `mdschema` checks pass.
- [ ] 5.5 Run a Chezmoi dry run and inspect its diff. Verify it changes only reviewed live targets.
- [ ] 5.6 Deliver the rendered diff for user review. Stop before any live configuration installation, staging, commit, or push.

## 6. Verify Live Vendor Features

- [ ] 6.1 After user installation, open a fresh shell. Verify proxy, one-shot direct, off, and restored routes.
- [ ] 6.2 Open Codex Desktop with OpenAI authentication. Verify remote access and cloud-agent controls remain available.
- [ ] 6.3 Run direct Claude `/status`. Verify it shows a full-scope Claude.ai login without an API key or profile.
- [ ] 6.4 Start direct Remote Control in server and interactive modes. Verify URLs and remote message round trips.
- [ ] 6.5 Start direct Claude with `--chrome`. Verify `/chrome` status and one harmless page inspection.
- [ ] 6.6 Open direct Claude Desktop. Verify native cloud features, Chrome connector access, and available Remote Control integration.
- [ ] 6.7 Send one proxied and one direct terminal request. Verify CPA Manager records only the proxied request.
- [ ] 6.8 Run the existing local usage reports. Verify route selection did not move vendor-written session records.
