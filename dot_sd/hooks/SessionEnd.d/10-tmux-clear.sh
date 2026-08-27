# Clear the tmux status segment when the session ends.
[ -x "$HOME/.local/bin/claude-tmux-status" ] || exit 0
exec "$HOME/.local/bin/claude-tmux-status" clear
