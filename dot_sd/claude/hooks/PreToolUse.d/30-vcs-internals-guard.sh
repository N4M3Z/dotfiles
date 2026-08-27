# File tools must not touch VCS internals.
payload=$(cat)
case "$(printf '%s' "$payload" | jq -r '.tool_name // empty')" in
    Edit|Write|NotebookEdit) ;;
    *) exit 0 ;;
esac
f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
case "/$f/" in
    */.git/*|*/.jj/*)
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Path is inside .git/.jj: file tools must not touch VCS internals. Drive changes through git or jj commands instead."}}'
        ;;
esac
exit 0
