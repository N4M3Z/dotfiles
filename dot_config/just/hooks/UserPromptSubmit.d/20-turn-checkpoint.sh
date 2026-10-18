# Record the prompt checkpoint: the diff baseline of the coming turn.
[ -f "$HOME/.config/just/claude/turn/checkpoint" ] || exit 0
exec sh "$HOME/.config/just/claude/turn/checkpoint" begin
