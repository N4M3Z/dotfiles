# Drop the prompt checkpoints this session wrote.
[ -f "$HOME/.config/just/claude/turn/checkpoint" ] || exit 0
exec sh "$HOME/.config/just/claude/turn/checkpoint" clear
