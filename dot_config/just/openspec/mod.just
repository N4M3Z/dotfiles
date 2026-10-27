set positional-arguments

# fzf picker over open OpenSpec changes
[no-cd]
review *args:
    @exec "{{ source_directory() }}/review" "$@"

# status segment: newest open OpenSpec change
[no-cd]
stat *args:
    @exec "{{ source_directory() }}/stat" "$@"
