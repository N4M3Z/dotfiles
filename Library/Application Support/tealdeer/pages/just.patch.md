
- Personal command tree (`~/.config/just`, PROV-0025): list every topic and recipe:

`just -g`

- Open the turn review picker (session footprint: working copies and recent changes) in tuicr:

`just -g tmux turn review`

- Wrap the current agent turn as one Jujutsu change (Stop hook, opt in with `touch .jj/turn-wrap`):

`just -g claude turn wrap`

- Focus Zed and open its Project Diff with all docks hidden:

`just -g zed diff`

- Resume the exact Claude session for the current pane:

`just -g claude resume`

- Resolve the canonical tmux session name for the current directory:

`just -g tmux session name`

- Start a long command detached from the caller, then wait for it:

`just -g job start {{name}} -- {{command}} && just -g job wait {{name}}`

- Run an agent through shared policy and capture:

`just -g agent run {{claude|codex|antigravity|grok|opencode}} {{arguments}}`
