---
title: "Turn-Scoped Review Through Jujutsu Turn Sealing"
description: "A Stop hook seals each agent turn as one Jujutsu change, so review panes and status segments show exactly the last turn without hidden git refs."
type: adr
category: architecture
tags:
    - claude-code
    - jujutsu
    - zed
    - tmux
    - review
status: accepted
created: 2026-08-25
updated: 2026-08-25
author: "Martin Zeman"
project: dotfiles
related:
    - "DOT-0001 Guard VCS Internals with a PreToolUse Hook"
responsible: ["Martin Zeman"]
accountable: ["Martin Zeman"]
consulted: []
informed: []
upstream:
    - "openspec/changes/turn-review-parity/"
---

# Turn-Scoped Review Through Jujutsu Turn Sealing

## Context and Problem Statement

The ChatGPT desktop app shows each agent turn as a reviewable unit: a per-turn diff, an end-of-turn file card, and an undo button. The Zed + Claude Code stack showed only one undifferentiated pile of uncommitted changes. A turn boundary must become a first-class VCS boundary before any pane can scope a diff to "the last turn". The mechanism must not corrupt Jujutsu repositories, must not seal user-curated work under a generated message, and must stay inert in repositories that did not opt in.

## Decision Drivers

- Zed's uncommitted-changes view diffs against git HEAD, and colocated Jujutsu points HEAD at `@-`. Sealing the working copy therefore resets the pane to the new turn for free.
- Codex implements turn checkpoints as non-standard `refs/codex/turn-diffs/` commits. Reports show repository bloat and libgit2 client failures. Jujutsu repositories must not carry such refs.
- Claude Code `/rewind` already restores files per turn. Undo needs no new mechanism.
- Curated change descriptions must survive automation.
- Repositories with review conventions (commit after approval) must be able to stay out.

## Considered Options

1. **Mirror Codex: hidden git refs per turn.** Pollutes the repository and conflicts with Jujutsu.
2. **Claude Code `/rewind` checkpoints only.** Gives undo but no VCS-visible turn boundary for panes and revsets.
3. **Git stash or auto-commit on every turn.** Fights the colocated Jujutsu workflow and clutters git history.
4. **Seal each turn as a Jujutsu change from a Stop hook.** Turn boundaries become ordinary changes: squashable, diffable, revsettable.
5. **A Zed fork patch that tracks agent edits in the editor.** High maintenance for what the VCS models natively.

## Decision Outcome

Chosen option: **seal each turn as a Jujutsu change from a Stop hook**, because it makes the turn a normal VCS object with zero hidden state.

The hook (`sd claude turn wrap`) is opt-in per repository (`.jj/turn-wrap`), skips empty turns, preserves user descriptions by wrapping with `jj new` instead of `jj commit`, and always exits zero. It prints a summary card (`systemMessage`) with the turn diffstat and the review and undo entry points. Review surfaces read the same boundary: Zed `git::Diff` (`space g d`), the tmux `±` status segment, and the tuicr step picker (`sd tmux turn review`). Undo remains `/rewind`; history repair remains `jj undo` and `jj squash`.

The session footprint spans repositories: `sd tmux turn repos` derives the opted-in set from the tmux pane directories, because one persistent session per project makes the tmux server the repo registry. No state file exists; the marker is the only membership authority. Each repository's own hook wraps only that repository, so concurrent sessions never race; the multi-repo picker, the spillover count, and the card's "elsewhere" line are read-only views over the footprint.

### Consequences

- Good: per-turn diffs, cards, and counters come from plain jj data. Any tool can query them.
- Good: no hidden refs, no repository bloat, no libgit2 hazards.
- Good: turn changes squash into curated concerns during review.
- Good: a multi-repo session reviews its whole footprint from one picker.
- Bad: turn granularity mixes concurrent manual edits into the same sealed change.
- Bad: an extra jj operation runs at every turn end in opted-in repositories.

## Amendment 2026-09-07: prompt checkpoints scope the diffstat

The `±` segment and the picker's first row now diff from a prompt checkpoint, not from the whole
working-copy change. A never-committed tree rendered its full size (66040+) on every pane, because
the working copy is the git scope, not the turn scope. A UserPromptSubmit hook records each footprint
repository's working-copy commit id after a snapshot; the segment renders `jj diff --from <id> --to @`.
This is the Claude Code checkpoint model (a checkpoint before every prompt) and the Codex review pane's
"Last turn" scope, expressed in jj. Turn sealing stays opt-in for repositories that want the boundary
in history; the checkpoint needs no marker and touches no history. The checkpoint rows live under
`~/.local/state/claude-turn`, one file per repository with the owning session id, and clear at
SessionEnd. That is the one state file this decision now carries.

## More Information

- Implementation: openspec change `turn-review-parity`.
- Claude Code checkpointing: <https://code.claude.com/docs/en/checkpointing>
- Codex review pane scopes: <https://learn.chatgpt.com/docs/code-review>
- Codex turn-diff ref problems: https://github.com/openai/codex/discussions/9618
