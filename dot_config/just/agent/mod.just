set positional-arguments

# hold a restored agent pane until Enter resumes it
[no-cd]
revive *args:
    @exec "{{ source_directory() }}/revive" "$@"

# launch an agent CLI with policy, attribution, and capture
[no-cd]
run *args:
    @exec "{{ source_directory() }}/run" "$@"
