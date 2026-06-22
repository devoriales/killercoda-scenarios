#!/bin/bash
set -e
. /root/.lab/api.sh

sem_login
PID="$(sem_pid)"
if [ -z "$PID" ] || [ "$PID" = "null" ]; then
  echo "Could not find the 'Acme Automation' project. Is Semaphore still up?"
  exit 1
fi

tasks="$(sem_get "/project/$PID/tasks")"
if echo "$tasks" | jq -e 'map(select(.status=="success")) | length >= 1' >/dev/null 2>&1; then
  echo "✅ A task run completed successfully — you drove Ansible from the web UI."
  exit 0
fi

if echo "$tasks" | jq -e 'map(select(.status=="running" or .status=="waiting")) | length >= 1' >/dev/null 2>&1; then
  echo "A task is still running — wait for it to finish, then click Check again."
  exit 1
fi

echo "No successful task run found yet."
echo "In the UI: Task Templates → 'Configure web app' → Run. Watch the log, then click Check."
exit 1
