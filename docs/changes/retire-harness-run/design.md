# Design

## The three launch paths after this change

```text
interactive    claude / codex / grok / agy / opencode   vendor binary on PATH
automation     rune run <profile> --clean --json        model, mode, supervision, clean state
fallback       sd agent run <provider>                  no rune on the machine
```

The fallback keeps the automated mode for a machine without rune, but nothing on this machine calls
it by default.

## What leaves the launcher

- The trailer. `check-authorship` in every runedeck repository validates a `Co-Authored-By` trailer
  against `authors.yaml`, and `<Harness> / <model> <N4M3Z@...>` is not an identity there. The author
  field is the contract, so automated mode sets `JJ_USER` and `JJ_EMAIL` in the shape the policy
  reads: `<Label> (<id>) <id@<provider>.noreply.nexus.local>`. Listing the identity stays each
  repository's decision.
- The capture debt functions. The launcher no longer knows whether capture succeeded, because it does
  not wait for it. session-sync records the debt itself, under the state directory rune's doctor reads.
- The PATH cleaning. With no wrapper on PATH there is nothing to skip. The resolver is
  `HARNESS_REAL_BIN_DIR`, then `type -P`, then the installer locations.
- The grok proxy route for an interactive start. `cliproxy.zsh` exports `GROK_MODELS_BASE_URL` and
  `GROK_CODE_XAI_API_KEY` with the Anthropic pair, since grok now starts by name. The launcher keeps
  its own injection for the fallback path.

## Review dispositions

Fable 5.1 pass, 2026-09-26: the grok proxy route was lost for a by-name start (fixed in
`cliproxy.zsh`), grok's interactive sandbox flag is already its config default
(`sandbox.profile = "workspace-local"`, so the by-name start keeps it), `sd agent revive` already
started providers by name, and the tealdeer pages already said `sd agent run`.

Astra pass (`gpt-6-astra`, clean state, 19 hits):

| Hit | Disposition |
|---|---|
| 1 abandon after an emptiness read discards a file saved in between | fixed: an empty claim gets its WIP description cleared, never abandoned |
| 2 a caller's `--sandbox danger-full-access` bypasses the pin, and `has_arg` reads past `--` | fixed for `--`: option scans stop there. Rejected for the override: the fallback supplies defaults a caller did not give, and enforcement is `rune run`'s job |
| 3 automated Claude gets a model and no policy | fixed: `--permission-mode plan` when absent |
| 4 an explicit `--model` runs one model and attributes another | fixed: the explicit value is the effective model for both |
| 5 the caller's next working-copy change is authored as the model | fixed: the caller's identity is restored before the change is made, on both paths |
| 6 finalize fails after the description is set: false warning, exit 0 | fixed: the warning names what to check, and a successful harness with a failed finalize exits 1 |
| 7 debt ownership moves before session-sync accepts `--status` | accepted as sequencing: the forge-data change follows today, and nothing calls the fallback by default (task 5.2) |
| 8 `${OPENCODE_PERMISSION:-{...}}` ends at the first `}` | fixed: the default is assigned apart from the export |
| 9 the record claims the check passes | fixed: the consequence says the field carries the identity and the repository lists it |
| 10 sanitization collides `a/b` with `a_b` and accepts `..` | fixed for the address: a leading, trailing, or doubled dot is refused. Collisions accepted: the id is the model's own name, and a repository lists what it accepts |
| 11 inherited descriptors above 2 keep a caller waiting | fixed: descriptors 3 to 15 are closed before the detached exec |
| 12 an exported function named `claude` satisfies `command -v` | fixed: `type -P` names executable files only |
| 13 the resolver MUST ignores PATH precedence | fixed: the requirement states the order and scopes the versions rule to the installer read |
| 14 "MUST start as rune run" forbids the fallback | fixed: by default, with the fallback named as the exception |
| 15 the timing test never creates the slow script | fixed: a blocking fixture that sleeps thirty seconds, exit asserted under three |
| 16 the absent-provider test checks grep, not the exit | fixed: status and stderr captured apart, 127 asserted |
| 17 a detached capture from an earlier run can land after the log is cleared | fixed: every run waits for its own capture line before the next test |
| 18 grok tests pass through the real proxy configuration | fixed: `CLIPROXY_BYPASS=1` for the test run |
| 19 the spec's replacement rule differs from the collapse the code does | fixed: the spec states the collapse and the trim |
