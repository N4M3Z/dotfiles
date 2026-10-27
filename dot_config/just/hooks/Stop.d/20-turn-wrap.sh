# Wrap the finished turn as its own jj change in opted-in repos.
[ -f "$HOME/.config/just/claude/turn/wrap" ] || exit 0
exec sh "$HOME/.config/just/claude/turn/wrap"
