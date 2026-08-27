# Lint every markdown file an agent writes, from the file's own
# directory, so linter configuration discovery starts at the file.
payload=$(cat)
case "$(printf '%s' "$payload" | jq -r '.tool_name // empty')" in
    Edit|Write) ;;
    *) exit 0 ;;
esac
f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')
case "$f" in
    */.claude/projects/*) exit 0 ;; # agent memory and session files carry no lint contract
    *.md) ;;
    *) exit 0 ;;
esac
cd "$(dirname "$f")" 2>/dev/null || exit 0
out=""
if command -v rumdl >/dev/null; then
    r=$(rumdl check "$f" 2>&1) || out="$out$r
"
fi
if command -v typos >/dev/null; then
    t=$(typos --force-exclude "$f" 2>&1) || out="$out$t
"
fi
if command -v vale >/dev/null && vale ls-config >/dev/null 2>&1; then
    v=$(vale --no-wrap --output line "$f" 2>&1) || out="$out$v
"
fi
[ -z "$out" ] || { printf '%s' "$out" >&2; exit 2; }
exit 0
