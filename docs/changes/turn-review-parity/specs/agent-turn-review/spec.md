# agent-turn-review

## Purpose

Turn-scoped review of agent work: each finished Claude Code turn becomes one reviewable Jujutsu change,
with an end-of-turn summary card, one-click review entry points, and screenshot capture into the agent prompt.

## ADDED Requirements

### Requirement: Turn wrapping on turn end

The Stop hook MUST wrap the working-copy change of an opted-in Jujutsu repository
when a Claude Code turn ends with file changes.

#### Scenario: Turn with changes in an opted-in repository

- WHEN a turn ends in a repository that contains `.jj/turn-wrap` and the working-copy change is not empty
- THEN the hook wraps the working copy as one Jujutsu change and the next turn starts from an empty working-copy change

#### Scenario: Empty turn

- WHEN a turn ends and the working-copy change contains no file changes
- THEN the hook makes no new change and prints nothing

#### Scenario: Repository without the marker

- WHEN a turn ends in a repository without `.jj/turn-wrap`
- THEN the hook exits without any repository operation

#### Scenario: Curated description present

- WHEN the working-copy change already has a non-empty description
- THEN the hook keeps that description and wraps with a new empty child change

#### Scenario: Jujutsu failure

- WHEN jj is missing, locked, or refuses to snapshot
- THEN the hook exits zero and the turn completes without an error

### Requirement: End-of-turn summary card

The Stop hook MUST print a summary card into the conversation for each wrapped turn.

#### Scenario: Wrapped turn card

- WHEN the hook wraps a turn
- THEN it prints a `systemMessage` JSON object that contains the turn diffstat and names the review and undo entry points

### Requirement: Prompt checkpoint

A UserPromptSubmit hook MUST record a checkpoint for each Jujutsu repository in the session footprint
before the turn starts. The checkpoint is the working-copy commit id after a snapshot, stored per
repository under the XDG state directory with the owning session id. This mirrors the Claude Code
checkpoint model, where every user prompt marks the baseline and the turn is everything after it.
No marker file, wrap, or repository history is involved.

#### Scenario: Prompt in a Jujutsu repository

- WHEN the user submits a prompt while the working directory is in a Jujutsu repository
- THEN the hook snapshots the working copy and records its commit id as the checkpoint of that repository

#### Scenario: Foreign repository owned by another session

- WHEN a footprint repository already holds a checkpoint from a different live session
- THEN the hook leaves that checkpoint in place, so the other session's turn keeps its baseline

#### Scenario: Session end

- WHEN the session ends
- THEN the hook removes the checkpoints that this session recorded

### Requirement: Status-bar turn diffstat

The tmux status bar MUST show the diffstat of the active pane's Jujutsu repository since its prompt
checkpoint. The segment never shows the whole uncommitted working copy: a never-committed tree
would render its full size on every pane.

#### Scenario: Turn with edits

- WHEN the pane's repository has a checkpoint and the diff from it to the working copy has insertions or deletions
- THEN the segment shows them in the form "N+ M-"

#### Scenario: Empty turn or no checkpoint

- WHEN the diff since the checkpoint is empty, or no checkpoint exists for the repository
- THEN the segment shows a bare "±" so the review click target stays present

#### Scenario: Foreign directory

- WHEN the directory is not in a Jujutsu repository
- THEN the segment is empty

### Requirement: One-click review

A click on the status-bar diffstat segment MUST open a review of the working tree.

#### Scenario: Segment click

- WHEN the user left-clicks the diffstat segment
- THEN a full-screen popup lists the working copy and recent changes as steps, and the selected step opens in tuicr

#### Scenario: This-turn step

- WHEN the review popup opens for a repository that holds a prompt checkpoint
- THEN the first step is the diff from the checkpoint to the working copy, the same scope as the segment

#### Scenario: Fresh diff on click

- WHEN the review popup opens
- THEN the launcher refreshes the Jujutsu snapshot and git export first, so the review reflects the current file state

#### Scenario: Zed diff segment click

- WHEN the user clicks the Zed diff segment
- THEN Zed comes to the front and opens its Project Diff multibuffer

### Requirement: Review scope keybindings

Zed MUST open a review multibuffer for each supported diff scope from the `space g` namespace.

#### Scenario: Scope keys

- WHEN the user presses `space g d`, `space g u`, `space g s`, or `space g b` in normal mode
- THEN Zed opens the uncommitted, unstaged, staged, or branch diff multibuffer

### Requirement: Screenshot into the prompt

A tmux binding MUST capture a window screenshot and paste its file path into the active pane.

#### Scenario: Window capture

- WHEN the user presses `prefix S` and clicks a window
- THEN the screenshot is stored under `~/Data/Captures` and its path, with a trailing space, is pasted into the active pane

#### Scenario: Cancelled capture

- WHEN the user cancels the capture
- THEN nothing is pasted

### Requirement: Session footprint

Review surfaces MUST cover the session footprint, not only the pane's repository.
Discovery is tiered: the current tmux session's pane repositories and the opted-in marker
repositories always appear, and jj op-log recency adds a bounded tail of recently active
repositories as the agent-work safety net. The machine-wide registry does not feed review
discovery. The marker file gates wrapping only and no state file exists.

#### Scenario: Multi-repo step list

- WHEN the review picker opens and other footprint repositories exist
  (session panes, markers, or the bounded recency tail)
- THEN their working copies and recent changes appear as steps, each prefixed with the
  repository name, and the selected step opens tuicr in that repository

#### Scenario: Bounded discovery

- WHEN many registered repositories exist on the machine
- THEN the picker lists only the session's repositories plus the bounded recency tail,
  so unrelated repositories add no rows

#### Scenario: Spillover indicator

- WHEN another Jujutsu repository in the same tmux session has a non-empty turn since its checkpoint
- THEN the diffstat segment appends the count of such repositories

#### Scenario: Footprint on the turn card

- WHEN a turn wraps and other opted-in repositories in the footprint have pending changes
- THEN the card lists those repositories with their diff counts

#### Scenario: Leaving the footprint

- WHEN a repository's marker file is removed or its panes close
- THEN it leaves the footprint without any other cleanup
