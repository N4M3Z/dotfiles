# EnterWorktree in a jj-colocated repo corrupts the jj/git marriage.
payload=$(cat)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // empty')
[ "$tool" = "EnterWorktree" ] || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
if [ -d "$root/.jj" ]; then
    echo 'jj-colocated repo: git worktrees conflict with jj. Use jj workspace add/forget instead (VersionControl/Jujutsu.md, JujutsuToolkit).' >&2
    exit 2
fi
exit 0
