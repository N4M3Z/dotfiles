# Snapshot the footprint so the ± segment and review see the turn.
[ -f "$HOME/.config/just/claude/turn/checkpoint" ] || exit 0
exec sh "$HOME/.config/just/claude/turn/checkpoint" snapshot
