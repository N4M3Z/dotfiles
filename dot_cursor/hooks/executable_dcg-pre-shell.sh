#!/bin/sh
# Cursor beforeShellExecution hook that runs dcg (Destructive Command Guard).
#
# Cursor sends {"command": "...", "cwd": "...", ...} on stdin and expects
# {"permission": "allow" | "deny", "user_message", "agent_message"} on stdout.
# dcg reads Claude-shaped input and answers with hookSpecificOutput, so this
# script translates both directions.
#
# Registered with failClosed in ~/.cursor/hooks.json: a crash here blocks the
# command instead of letting it through. An empty command is allowed because
# there is nothing to inspect.
# Source: https://github.com/N4M3Z/dotfiles
set -u
PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin"
export PATH CURSOR_IDE=1

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.command // empty') || exit 1
if [ -z "$command" ]; then
    printf '{"permission":"allow"}\n'
    exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    cd "$cwd" || exit 1
fi

# dcg prints its human-readable box on stderr and one JSON line on stdout.
verdict=$(printf '%s' "$input" \
    | jq -c '{tool_name: "Bash", tool_input: {command: .command}}' \
    | dcg 2>/dev/null \
    | jq -c 'fromjson? | select(type == "object") | .hookSpecificOutput // empty' -R) || exit 1

if [ -z "$verdict" ]; then
    printf '{"permission":"allow"}\n'
    exit 0
fi

printf '%s' "$verdict" | jq -c '
  if .permissionDecision == "deny" then
    {
      permission: "deny",
      user_message: ("dcg blocked " + (.ruleId // "a destructive command") + ". Run it yourself if it is intended."),
      agent_message: (.permissionDecisionReason // "Blocked by dcg.")
    }
  else
    {permission: "allow"}
  end'
