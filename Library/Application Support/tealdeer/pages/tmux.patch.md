- List stable session identifiers with readable names:

`tmux list-sessions -F '#{session_id} #{session_name}'`

- Attach by stable identifier when a session name contains `.` or `:`:

`tmux attach-session -t '{{session_id}}'`

- Open the local command menu from an attached client:

`prefix + ?`

- Reload the complete local configuration:

`prefix + R`

- Review the working copy or a recent change (also: click the `±` status segment):

`sh ~/.sd/tmux/turn/review`

- Open the agents picker with project names:

`prefix + u`

- Capture a window screenshot into the active pane:

`prefix + S`

- Render the project README (also: click the path status segment):

`prefix + g`
