# File tools must not touch VCS internals. The block speaks the
# portable protocol (stderr plus exit 2), which Claude and Codex both
# honor; Codex ignores permissionDecision JSON.
payload=$(cat)
case "$(printf '%s' "$payload" | jq -r '.tool_name // empty')" in
    Edit|Write|NotebookEdit) ;;
    *) exit 0 ;;
esac
f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
case "/$f/" in
    */.git/*|*/.jj/*)
        echo 'Path is inside .git/.jj: file tools must not touch VCS internals. Drive changes through git or jj commands instead.' >&2
        exit 2
        ;;
esac
exit 0
