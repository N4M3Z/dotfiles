set positional-arguments

# status segment: diffstat of the working copy
[no-cd]
diff *args:
    @exec "{{ source_directory() }}/diff" "$@"

# jj roots from vcstool manifests and tmux panes
[no-cd]
registry *args:
    @exec "{{ source_directory() }}/registry" "$@"

# jj roots opted into turn wrap (.jj/turn-wrap)
[no-cd]
repos *args:
    @exec "{{ source_directory() }}/repos" "$@"

# turn review picker, opens the pick in tuicr
[no-cd]
review *args:
    @exec "{{ source_directory() }}/review" "$@"
