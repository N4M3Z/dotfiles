# Design: turn-review-parity

## Context

See proposal.md - Why. Constraints that shape the approach:

- Repositories are Jujutsu-colocated. Git HEAD tracks `@-`, so Zed's uncommitted view always equals the jj working-copy change.
- The dotfiles working copy is shared with concurrent agent sessions. Feature edits must stay separable from unrelated churn.
- The Claude sandbox cannot reach the tmux socket or write live config outside approved tools. Live application stays manual.
- Helper scripts deploy through the `dot_sd` tree (`sd <namespace> <command>`).

## Goals / Non-Goals

Goals:

- One VCS boundary per agent turn, readable by every review surface.
- Review entry points that need one keypress or one click.
- Zero repository pollution and zero behavior in repositories that did not opt in.

Non-Goals:

- No replication of the ChatGPT cloud features (best-of-N, cloud handoff). Claude Code equivalents exist.
- No new undo mechanism. `/rewind` and `jj undo` cover it (see DOT-0005).
- No Zed fork patch for this feature.

## Decisions

- **Wrap turns with jj, not hidden git refs**: recorded in DOT-0005 with alternatives.
- **Opt-in marker `.jj/turn-wrap`**: a file inside `.jj/` is per-machine, untracked, and needs no config-key support in jj. Alternative (repo config key) risks unknown-key warnings.
- **tmux is the repo registry**: the session footprint derives from `tmux list-panes` directories filtered by the marker (`sd tmux turn repos`). One persistent session per project makes the pane set authoritative; a state file under `~/.local/state` would only go stale.
- **`jj new` for described changes, `jj commit` for undescribed ones**: automation must never overwrite a curated description.
- **Each repo's own hook wraps only its own repo**: cross-repo wrapping would race the other sessions; the multi-repo layer stays read-only aggregation.
- **Status segment uses `--ignore-working-copy`**: the segment renders every status interval; skipping the snapshot avoids lock contention with live sessions. Freshness comes from the sessions' own jj operations.
- **Prompt checkpoint, not the working copy, scopes the diffstat**: Claude Code checkpoints before every
  user prompt, and the Codex app's review pane offers "Last turn" beside the git scopes. The segment
  mirrors that: a UserPromptSubmit hook (`sd claude turn checkpoint begin`) snapshots each footprint
  repo and records the working-copy commit id, the Stop hook snapshots again, and the segment renders
  `jj diff --from <checkpoint> --to @`. jj keeps the superseded commit reachable through the op log,
  so no wrap, marker, or history is needed. The whole-working-copy stat showed 66040+ on a
  never-committed tree, which is the git-vs-turn gap this fixes. The checkpoint row carries the
  owning session id: a prompt resets only its own repo and foreign rows it owns, so two sessions in
  one tmux session never reset each other's baseline. The row is one file per repo under
  `~/.local/state/claude-turn`, cleared at SessionEnd; a stale row degrades to the bare `±`.
- **Shift+Enter forwards Ctrl+J (`terminal::SendKeystroke`)**: Zed's keymap parser rejects raw control bytes in strings, so a CSI-u `SendText` binding cannot be stored. Ctrl+J is Claude Code's universal newline.
- **Summary card via Stop-hook `systemMessage`**: the only supported way to render an end-of-turn card inside the Claude Code conversation.

## Risks / Trade-offs

- [Concurrent sessions share the working copy] → sealed turns mix their edits; `jj split` and `jj squash` separate them during review.
- [`extended-keys always` confuses an old TUI] → revert to `on` and remove `extended-keys-format`; documented in the demo file.
- [Turn cards add conversation noise] → the card prints only for non-empty turns in opted-in repositories.
- [Status segment shows stale counts up to one interval] → acceptable; the seal itself refreshes it.

## Migration Plan

1. User reloads tmux (`prefix R`) and starts a new Claude session (Stop hook loads at session start).
2. Opt in per repository: `touch .jj/claude-turn-seal`.
3. Rollback: remove the marker file, the hook entry, and the status segment; all are independent.
