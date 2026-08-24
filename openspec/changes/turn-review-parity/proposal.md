# Proposal: turn-review-parity

## Why

The ChatGPT desktop app gives one-click review of agent work: a live Review pane, per-turn diff scope, end-of-turn file cards, and undo. The Zed + Claude Code + tmux stack had the raw pieces but no turn-scoped review surface. This change brings that parity with local, inspectable tools.

## What Changes

- Add a Claude Code Stop hook script `sd claude turn wrap`. It wraps each finished agent turn as one Jujutsu change and prints an end-of-turn summary card into the conversation.
- The hook is opt-in for each repository through a `.jj/turn-wrap` marker file.
- Add `sd tmux turn repos`. It derives the session footprint (opted-in repos) from the tmux pane directories; no registry state exists.
- Add `sd tmux turn diff`. It renders the working-copy diffstat ("± N+ M-") with a spillover count for other dirty footprint repos.
- Add `sd tmux turn review`. It offers the footprint's working copies and recent changes as steps and opens the picked one in tuicr.
- Add a clickable `review` segment to the theo status-bar theme. A click opens tuicr on the working tree in a popup.
- Add Zed review-pane keybindings: `space g d` uncommitted, `space g u` unstaged, `space g s` staged, `space g b` branch against the merge base. `space g g` replaces bare `space g` for the git panel.
- Add `sd claude appshot` and the tmux `prefix S` binding. It captures a window screenshot and pastes the file path into the active pane.
- Register the turn-seal hook in the Claude Code user settings template (`dot_claude/private_settings.json.tmpl`).
- Undo stays on Claude Code `/rewind` and the Jujutsu operation log. No hidden git refs are created. This decision is recorded in **DOT-0005 Turn-Scoped Review Through Jujutsu Turn Sealing** (new).
- Source configuration changes only. Live application through `chezmoi apply` stays a separate, user-approved step. The live copies applied during development match the source.

## Capabilities

### New Capabilities

- `agent-turn-review`: turn-scoped diff review, end-of-turn summary cards, one-click review entry points, and screenshot capture into the agent prompt.

### Modified Capabilities

None.

## Impact

- `dot_sd/claude/executable_turn-seal` (new), `dot_sd/claude/executable_appshot` (new), `dot_sd/tmux/executable_turn-diff` (new).
- `dot_config/tmux/tmux.conf`, `dot_config/tmux/theme-theo.conf.tmpl`: status segment, click dispatch, `prefix S`.
- `dot_config/zed/keymap.json`: `space g` namespace.
- `dot_claude/private_settings.json.tmpl`: Stop hook entry.
- Related decisions: DOT-0005 (new), DOT-0001 (hook-guarded VCS internals; turn-seal drives all history changes through jj commands).
- No credentials, no network, no live service changes.
