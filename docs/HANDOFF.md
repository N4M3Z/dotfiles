# Handoff

Written 2026-09-23 by the Fable session `setup/vale` for the model that takes over. Durable
architecture lives in [../README.md](../README.md). Everything below is mid-flight state. Verify
against the repos before acting, and delete this section when the items are closed.

## Rules the owner set in this thread

- Never leak to Kimi or any model served from China: synthetic text only, always through
  `rune run --clean-harness-state` (renamed to `--clean` in the next rune build, old spelling stays
  as a hidden alias). Deck rule `UntrustedModels` says so.
- Start long harness jobs yourself with `sd job start`, detached, one background `until [ -f rc ]`
  wait, one notification at the end. Never a per-event monitor, never hand the start line to the
  owner. Kimi, Grok, Lumo, Codex spend is pre-authorized. Keep Fable spend minimal.
- Run `gh`, `jj git push`, `rune`, `grok`, `codex`, `opencode` as the whole command line, no
  `cd &&` prefix, no pipe: the sandbox exclusion matches the full line.
- The owner signs and pushes. Stop at a local jj change plus bookmark. `RemoteWrites` forbids
  `gh pr create`, `gh pr close`, and any push to a branch you did not create.
- Do not chain unrelated actions in one shell line. dcg blocks `rm -rf`, `mv` without `-f/-n`,
  `git branch -f`, and redirects to `$TMPDIR`. Use `/tmp/claude/<literal>` for scratch.

## What is on main (signed by the owner)

Deck, skeleton, bench, cli, docs, seer, site: STE advisory levels, `STE.Overused*`, Core rules
(`NoEmDash` the one error, `NegativeParallelism`, `UndefinedTerm`, `BoldOveruse`, `AIVocabulary*`),
`ai-tells` v1.37.0 vendored on probation, em dash sweeps. Dotfiles: user-level Vale, severity-split
lint hook, `-run` profile twins retired, `tells-judging` change and proof.

## Unsigned, ready for the owner's sign lines

| Repo | Bookmark | Content |
|---|---|---|
| deck | `change/untrusted-models` | `UntrustedModels` rule + `.vale.ini` note on fork vs upstream |
| deck | `change/em-dash-sweep` | 39 em dashes swept, rebase onto main after the rule lands |
| skeleton | `change/em-dash-sweep` | rebased, tree green |
| dotfiles (this workspace) | `change/tells-judging` | two commits, includes the proof |
| forge-provision | `change/brew-mise` | `brew "mise"` in the Brewfile |

Sign line shape, per bookmark:

```sh
jj sign -r <bookmark> && jj bookmark set main -r <bookmark> && jj git push --bookmark main && jj bookmark delete <bookmark>
```

## The fork: N4M3Z/vale-ai-tells

Checkout `~/Developer/N4M3Z/vale-ai-tells`, remotes `origin` (fork) and `upstream` (tbhb). Nothing
pushed anywhere yet.

- `bench/pilot-2026-09-22`: six commits, the pipeline, 40-document corpus, final report
  (`bench/results/tells-pilot/2026-09-23T07-46-18Z/`), adjudication, three phase recordings with
  paths redacted. PII scanned: no name, email, host, or token value.
- `feat/contrastive-reveal` (currently checked out): `upstream/main` plus two cherry-picks, the
  `ContrastiveReveal` rule and its changelog guard. 5 files, 65 lines. This is the PR branch.
- Working tree there has 615 untracked files under `bench/` (leftovers from the other branch, do
  not add) and a modified `.config/mise/mise.lock` from `mise install` (do not commit).
- PR body draft is in the session transcript. The template needs Summary, Why, Verification, Risk,
  Related. Owner files it.

Result to quote: 212 confirmed tells (two of three judges), Vale recall 0.392, one new rule with
zero hits across 196,387 pre-LLM paragraphs. Recall is a floor (span-level credit).

## Open finding on upstream's test suite

`mise run test` fails on upstream `main` itself, not because of the rule: `test-commit-past-tense`
misses all five subjects under the mise-installed `vale@3.17.0`, and the same subject fires under
vale 3.22 (`/opt/homebrew/bin/vale`). `CommitPastTense` uses `scope: raw` with `\A` across two
`raw` entries, a behaviour that changed between the versions. CI runs `mise run test` after
`jdx/mise-action`, so it likely uses the same pin. Worth a sentence in the PR's Verification
(`test-fires` 1876 to 1884, `test-clean` green, `test-commit-past-tense` red on upstream too) and
possibly a separate issue to tbhb. Not verified: whether CI is actually red today.

## Waiting on the cli session (runedeck/cli)

- Codex under clean state: root cause found (codex drops a global `--config` when the subcommand
  has its own, so `model_provider="cliproxyapi"` was lost and codex hit `api.openai.com` with no
  auth). Fix and the `--clean` rename are in one commit, id promised. When it arrives:
  re-probe `rune run astra@codex --clean --json --timeout 3m --repo /tmp/claude/scratch-repo
  'Reply with exactly the word: pong'`, then sweep the flag spelling in `bench/scripts/generate.sh`,
  `bench/scripts/judge.sh`, `docs/proofs/cross-harness-tells-judging/record.sh` and its spec, and
  the deck rule, then re-record the proof (`sd job start`, see the README there).
- All 60 astra corpus calls are marked `clean_harness_state: false`. Owner said no rerun now.

## Not done, by choice

- Noun-triad rule: upstream's fixture declares noun lists a false positive, so it belongs in the
  deck's Core, not the fork. The owner has not asked for it.
- mise in runedeck: recommended against, because `tool-versions` plus `Makefile` already cover both jobs
  with digest pins (SKEL-0003).
- The setup workshop rule `WholeLineForExcludedCommands` is in both rule directories, uncommitted.
