set positional-arguments

# show a detached job's log, -f follows it
[no-cd]
log *args:
    @exec "{{ source_directory() }}/log" "$@"

# start a command detached: start <name> -- <command>
[no-cd]
start *args:
    @exec "{{ source_directory() }}/start" "$@"

# block until a detached job ends, exit with its code
[no-cd]
wait *args:
    @exec "{{ source_directory() }}/wait" "$@"
