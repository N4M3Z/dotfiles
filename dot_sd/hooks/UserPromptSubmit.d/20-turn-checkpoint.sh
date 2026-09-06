# Record the prompt checkpoint: the diff baseline of the coming turn.
[ -f "$HOME/.sd/claude/turn/checkpoint" ] || exit 0
exec sh "$HOME/.sd/claude/turn/checkpoint" begin
