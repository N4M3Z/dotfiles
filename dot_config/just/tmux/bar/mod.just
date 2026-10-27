set positional-arguments

# status segment: battery glyph and percent
[no-cd]
battery *args:
    @exec "{{ source_directory() }}/battery" "$@"

# status segment: git branch, marked when dirty
[no-cd]
git *args:
    @exec "{{ source_directory() }}/git" "$@"

# status segment: jj bookmark or change id
[no-cd]
jj *args:
    @exec "{{ source_directory() }}/jj" "$@"

# status segment: network throughput (parked)
[no-cd]
net *args:
    @exec "{{ source_directory() }}/net" "$@"
