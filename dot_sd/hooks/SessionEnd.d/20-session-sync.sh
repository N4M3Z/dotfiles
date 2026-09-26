# Capture the session that just ended: forge-data's session-sync syncs the
# one session the payload names, detached, so the exit never waits on it.
# A miss leaves a debt file under ~/.local/state/rune/capture-debt.
sync="$HOME/.local/bin/session-sync"
[ -x "$sync" ] || sync="$HOME/Developer/N4M3Z/forge-data/scripts/session-sync"
[ -x "$sync" ] || exit 0
payload=$(cat)
nohup "$sync" "$payload" >/dev/null 2>&1 </dev/null &
exit 0
