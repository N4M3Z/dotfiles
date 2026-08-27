# Worktree-isolated subagents conflict with jj-colocated repos.
payload=$(cat)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // empty')
[ "$tool" = "Agent" ] || exit 0
printf '%s' "$payload" | grep -q '"isolation"[[:space:]]*:[[:space:]]*"worktree"' || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
if [ -d "$root/.jj" ]; then
    echo 'jj-colocated repo: worktree-isolated agents conflict with jj. Spawn without isolation and give each agent its own jj workspace (jj workspace add; see JujutsuToolkit).' >&2
    exit 2
fi
exit 0
