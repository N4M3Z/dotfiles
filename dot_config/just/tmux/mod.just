set positional-arguments

# status-bar segments
mod bar

# session naming
mod session

# turn review segment and picker
mod turn

# gitui popup, guarded to git repos
[no-cd]
gitui *args:
    @exec "{{ source_directory() }}/gitui" "$@"

# markdown browser popup: fzf list with glow preview
[no-cd]
glow *args:
    @exec "{{ source_directory() }}/glow" "$@"

# jjui popup, guarded to jj repos
[no-cd]
jjui *args:
    @exec "{{ source_directory() }}/jjui" "$@"
