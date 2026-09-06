# Flip the tmux status segment to working when a prompt starts.
[ -x "$HOME/.local/bin/claude-tmux-status" ] || exit 0
exec "$HOME/.local/bin/claude-tmux-status" working
