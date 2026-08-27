# Wrap the finished turn as its own jj change in opted-in repos.
[ -f "$HOME/.sd/claude/turn/wrap" ] || exit 0
exec sh "$HOME/.sd/claude/turn/wrap"
