# sd

> Run personal dispatch commands from the chezmoi-managed `sd` command tree.
> Subcommands cover agents, Zed, tmux, GitHub, and local tldr pages.

- List available dispatch commands:

`sd`

- Show local and upstream tldr pages:

`sd tldr`

- Open the turn review picker (session footprint: working copies and recent changes) in tuicr:

`sd tmux turn review`

- Wrap the current agent turn as one Jujutsu change (Stop hook; opt in with `touch .jj/turn-wrap`):

`sd claude turn wrap`

- Focus Zed and open its Project Diff with all docks hidden:

`sd zed diff`

- Resume the exact Claude session for the current pane:

`sd claude resume`

- Resolve the canonical tmux session name for the current directory:

`sd tmux session-name`

- Run an agent through shared policy and capture:

`sd agent run {{claude|codex|antigravity|grok|opencode}} {{arguments}}`
