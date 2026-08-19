## 1. Protect Planning Artifacts

- [ ] 1.1 Add `openspec` to `.chezmoiignore`. Verify that `chezmoi diff --source .` contains no OpenSpec target files.

## 2. Configure the Shared Codex Default

- [ ] 2.1 Keep `model_provider = "openai"` and define the proxy `env_key`. Verify that the rendered TOML parses.
- [ ] 2.2 Implement targeted legacy profile migration. Verify that fixtures remove known profiles and preserve an unknown profile.
- [ ] 2.3 Remove the unused draft `review.config.toml`. Verify that no repository reference requires that file.

## 3. Route Terminal Codex

- [ ] 3.1 Add all routing branches to the managed `codex` wrapper. Verify each branch with a fake `harness-run`.
- [ ] 3.2 Keep client keys out of arguments. Verify that the fake launcher log contains only the variable name and provider override.
- [ ] 3.3 Make terminal Codex select the standalone executable. Verify that focused tests cover both Codex installations without changing other harnesses.
- [ ] 3.4 Preserve user arguments and proxy exit codes. Verify spaces, argument order, and a nonzero child exit.

## 4. Unify Proxy Controls

- [ ] 4.1 Define `noproxy` and `cliproxy` before credential checks. Verify both functions when `~/.env` is unreadable.
- [ ] 4.2 Unset all Anthropic proxy and API-key variables in `noproxy`. Verify that a fake `claude` child receives none.
- [ ] 4.3 Update all `cliproxy` actions for both Codex routes. Verify missing keys and both flag states with Zsh tests.
- [ ] 4.4 Remove `codex-proxy` and the Rune binary override. Verify that a Rune dry run resolves the normal `codex` command.

## 5. Validate the Source

- [ ] 5.1 Run JSON, YAML, Bash, Zsh, ShellCheck, and template checks. Verify that every command exits successfully.
- [ ] 5.2 Run the routing, harness, and profile-migration tests. Verify that every branch and fixture passes.
- [ ] 5.3 Validate the OpenSpec change and ForgeADR structure. Verify that strict OpenSpec and `mdschema` checks pass.
- [ ] 5.4 Run `chezmoi diff --source .` and inspect the scoped routing changes. Stop without applying, staging, committing, or pushing.
