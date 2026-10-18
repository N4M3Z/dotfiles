set positional-arguments

# cli of the personal Zed Dev build, arguments pass through
[no-cd]
dev *args:
    @exec "{{ source_directory() }}/dev" "$@"

# focus Zed and open Project Diff with docks hidden
[no-cd]
diff *args:
    @exec "{{ source_directory() }}/diff" "$@"

# open paths in the Zed instance this terminal belongs to
[no-cd]
open *args:
    @exec "{{ source_directory() }}/open" "$@"

# rebuild the personal Zed fork on the newest preview
[no-cd]
rebuild *args:
    @exec "{{ source_directory() }}/rebuild" "$@"

# publish the rebuilt DMG: tag, release, cask bump
[no-cd]
release *args:
    @exec "{{ source_directory() }}/release" "$@"
