set positional-arguments

# turn-scoped review: checkpoint and wrap
mod turn

# screenshot one window into ~/Data/Captures and print the path
[no-cd]
appshot *args:
    @exec "{{ source_directory() }}/appshot" "$@"

# resume the Claude session bound to this tmux window
[no-cd]
resume *args:
    @exec "{{ source_directory() }}/resume" "$@"

# resurrect forwarder for agent revive claude
[no-cd]
revive *args:
    @exec "{{ source_directory() }}/revive" "$@"

# set the tmux @agent flag: working, attention, clear
[no-cd]
status *args:
    @exec "{{ source_directory() }}/status" "$@"
