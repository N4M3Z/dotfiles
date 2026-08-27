# Flip the tmux status segment to attention when a turn ends.
[ -x "$HOME/.local/bin/claude-tmux-status" ] || exit 0
exec "$HOME/.local/bin/claude-tmux-status" attention
