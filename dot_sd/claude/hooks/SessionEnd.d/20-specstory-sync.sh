# Refresh specstory markdown capture for the project, detached, so a
# long sync against the session database never holds the exit.
nohup specstory sync --silent >/dev/null 2>&1 </dev/null &
exit 0
