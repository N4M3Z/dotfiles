# Handoff

Written 2026-09-23 by the Fable session `setup/vale` for the model that takes over. Durable
architecture lives in [../README.md](../README.md). Everything below is mid-flight state. Verify
against the repos before acting, and delete this section when the items are closed.

## Rules the owner set in this thread

- Never leak to Kimi or any model served from China: synthetic text only, always through
  `rune run --clean` (rune 0.6.0, the old `--clean-harness-state` spelling is gone). Deck rule
  `UntrustedModels` says so.
- Start long harness jobs yourself with `just -g job start`, detached, one background `until [ -f rc ]`
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
| skeleton | `change/em-dash-sweep` | rebased, tree green |
| dotfiles (this workspace) | `change/tells-judging` | spec, proof on rune 0.6.0, this handoff |
| forge-provision | `change/brew-mise` | `brew "mise"` in the Brewfile |
| dotfiles (default workspace) | `change/rune-opus-5-5` | `opus` is `claude-opus-5-5`, 1M context, applied live |

Sign line shape, per bookmark:

```sh
jj sign -r <bookmark> && jj bookmark set main -r <bookmark> && jj git push --bookmark main && jj bookmark delete <bookmark>
```

## The fork: N4M3Z/vale-ai-tells

Checkout `~/Developer/N4M3Z/vale-ai-tells`, remotes `origin` (fork) and `upstream` (tbhb). The
owner pushed the fork's `main` and `bench/pilot-2026-09-22` at `f87f3a6`. The PR branch and the
flag-rename commit `49f9aa6` are not pushed, and no PR is filed.

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

## Rune 0.6.0 (cli 807dac69 and after)

- `--clean` replaced `--clean-harness-state`, and codex under clean state works: astra answered
  `pong` on gpt-6-astra with `"clean":true`. Rune c47af0ea also renamed the JSON field from
  `clean_harness_state` to `clean`. The flag is swept in the fork's bench scripts (pilot branch
  `49f9aa6`, unpushed), the deck rule, and the proof, which runs all four harnesses as normal scenes.
- The proof reads the fork scripts from the worktree `~/Developer/N4M3Z/vale-ai-tells-pilot`, so a
  branch switch in the PR checkout cannot break it.
- All 60 astra corpus calls in the pilot are still marked `clean_harness_state: false`. The owner
  said no rerun now.
- Opus 5.5 and Grok 4.7 both answer under `--clean`: `rune run claude --model claude-opus-5-5` and
  `rune run grok@grok`.

## Not done, by choice

- Noun-triad rule: upstream's fixture declares noun lists a false positive, so it belongs in the
  deck's Core, not the fork. The owner has not asked for it.
- mise in runedeck: recommended against, because `tool-versions` plus `Makefile` already cover both jobs
  with digest pins (SKEL-0003).
- The setup workshop rule `WholeLineForExcludedCommands` is in both rule directories, uncommitted.
