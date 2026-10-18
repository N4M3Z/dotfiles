set positional-arguments

# tmux session name for a directory, reusing a live one
[no-cd]
name *args:
    @exec "{{ source_directory() }}/name" "$@"
