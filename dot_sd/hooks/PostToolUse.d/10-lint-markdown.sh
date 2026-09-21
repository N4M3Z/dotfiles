# Lint every markdown file an agent writes, from the file's own
# directory, so linter configuration discovery starts at the file.
# rumdl and typos findings block: stderr, exit 2. Vale findings split
# by level. An error blocks with them. A warning or suggestion goes
# back on stdout as additionalContext, which the harness adds to the
# agent's context without undoing the write. Plain stdout would only
# reach the debug log, so the advice is one JSON object.
payload=$(cat)
case "$(printf '%s' "$payload" | jq -r '.tool_name // empty')" in
    Edit|Write) ;;
    *) exit 0 ;;
esac
f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')
case "$f" in
    */.claude/projects/*) exit 0 ;; # agent memory and session files carry no lint contract
    /tmp/*|/private/tmp/*|/var/folders/*) exit 0 ;; # scratch files carry no lint contract
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
advice=""
if command -v vale >/dev/null && vale ls-config >/dev/null 2>&1; then
    # JSON keeps the level and the replacement per finding; the line
    # format flattens both. The flag overrides a project MinAlertLevel
    # so suggestions still arrive as advice.
    v=$(vale --minAlertLevel=suggestion --output=JSON "$f" 2>&1)
    if [ -n "$v" ] && printf '%s' "$v" | jq -e 'type == "object"' >/dev/null 2>&1; then
        lines=$(printf '%s' "$v" | jq -r --arg f "$f" '
            to_entries[] | .value[] |
            "\($f):\(.Line):\(.Span[0]) \(.Severity) \(.Check): \(.Message)"
            + (if .Action.Name == "replace"
               then " -> " + ((.Action.Params // []) | join(" | "))
               else "" end)')
        errors=$(printf '%s' "$v" | jq '[.[][] | select(.Severity == "error")] | length')
        if [ "$errors" -gt 0 ]; then
            out="$out$lines
"
        else
            advice="$lines"
        fi
    else
        advice="vale did not run: $v"
    fi
fi
# A block carries the advice too, so the agent sees every finding once.
[ -z "$out" ] || { printf '%s%s' "$out" "$advice" >&2; exit 2; }
[ -z "$advice" ] && exit 0
printf '%s' "$advice" | jq -Rs '{hookSpecificOutput: {hookEventName: "PostToolUse",
    additionalContext: ("Vale advice for the file you wrote, not a block. Rewrite a flagged sentence when the meaning survives it, keep the wording when it does not.\n" + .)}}'
exit 0
