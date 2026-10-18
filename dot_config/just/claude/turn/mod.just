set positional-arguments

# record, snapshot, or clear the prompt checkpoint
[no-cd]
checkpoint *args:
    @exec "{{ source_directory() }}/checkpoint" "$@"

# seal the finished turn as its own jj change
[no-cd]
wrap *args:
    @exec "{{ source_directory() }}/wrap" "$@"
