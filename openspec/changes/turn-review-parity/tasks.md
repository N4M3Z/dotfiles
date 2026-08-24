# Tasks: turn-review-parity

## 1. Scripts

- [x] 1.1 Add `dot_sd/claude/turn/executable_wrap` (wrap + summary card with footprint counts); verify with the scratch-repo cases: empty turn, undescribed turn, described turn, no marker, elsewhere aggregation.
- [x] 1.2 Add `dot_sd/tmux/turn/executable_diff` (status diffstat + spillover count); verify it prints "± N+ M-" with changes, a bare "±" when clean, and "⁺N" for other dirty footprint repos.
- [x] 1.3 Add `dot_sd/claude/executable_appshot`; verify `sh -n` passes and the script prints a path only for a non-empty capture.
- [x] 1.4 Add `dot_sd/tmux/turn/executable_repos` (pane-footprint derivation) and `dot_sd/tmux/turn/executable_review` (multi-repo step picker); verify with the stubbed fzf and tuicr tests: first row, cross-repo working copy, cross-repo change.

## 2. tmux

- [x] 2.1 Add the `review` status segment to `dot_config/tmux/theme-theo.conf.tmpl`; verify the segment appears in status-right with the `range=user|review` wrapper.
- [x] 2.2 Add the `review` branch to the MouseDown1Status dispatch and the `prefix S` appshot binding in `dot_config/tmux/tmux.conf`; verify brace balance by reading the block.
- [ ] 2.3 Reload the live tmux server (`prefix R`) and verify `tmux show -sv extended-keys` prints `always`; manual, the sandbox cannot reach the socket.

## 3. Zed

- [x] 3.1 Add the `space g` namespace (`g`, `d`, `u`, `s`, `b`) and the Terminal `shift-enter` forwarding to `dot_config/zed/keymap.json`; verify comment-stripped JSON parses with jq.

## 4. Claude Code settings

- [x] 4.1 Register the turn-seal Stop hook in `dot_claude/private_settings.json.tmpl`; verify the rendered template parses and lists two Stop hooks.

## 5. Verification and hygiene

- [x] 5.1 Scratch-repo end-to-end test: seal produces the `systemMessage` card with the diffstat and jq accepts the JSON.
- [x] 5.2 Add `openspec` to `.chezmoiignore`; verify `chezmoi ignored` (or the file content) lists it.
- [ ] 5.3 Run a Chezmoi dry run (`chezmoi diff`) and confirm only the intended targets change; manual while the sandbox blocks the chezmoi state db.
