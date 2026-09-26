# Capture the session before compaction rewrites its context: the same
# scoped, detached session-sync call as SessionEnd.
sync="$HOME/.local/bin/session-sync"
[ -x "$sync" ] || sync="$HOME/Developer/N4M3Z/forge-data/scripts/session-sync"
[ -x "$sync" ] || exit 0
payload=$(cat)
nohup "$sync" "$payload" >/dev/null 2>&1 </dev/null &
exit 0
