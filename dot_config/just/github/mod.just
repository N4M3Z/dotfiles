set positional-arguments

# replay a jj bookmark through the GitHub commit API
[no-cd]
push *args:
    @exec "{{ source_directory() }}/push" "$@"
