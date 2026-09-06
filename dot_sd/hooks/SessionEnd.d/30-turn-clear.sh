# Drop the prompt checkpoints this session wrote.
[ -f "$HOME/.sd/claude/turn/checkpoint" ] || exit 0
exec sh "$HOME/.sd/claude/turn/checkpoint" clear
