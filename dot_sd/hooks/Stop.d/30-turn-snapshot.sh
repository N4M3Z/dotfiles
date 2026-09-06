# Snapshot the footprint so the ± segment and review see the turn.
[ -f "$HOME/.sd/claude/turn/checkpoint" ] || exit 0
exec sh "$HOME/.sd/claude/turn/checkpoint" snapshot
