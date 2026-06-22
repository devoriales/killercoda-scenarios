#!/bin/bash
set -e
. /root/.lab/api.sh

sem_login
PID="$(sem_pid)"
if [ -z "$PID" ] || [ "$PID" = "null" ]; then
  echo "Could not find the 'Acme Automation' project. Is Semaphore still up?"
  exit 1
fi

count="$(sem_get "/project/$PID/templates" | jq 'length' 2>/dev/null || echo 0)"
if [ "${count:-0}" -lt 1 ]; then
  echo "No task template found yet."
  echo "In the UI: Task Templates → New Template → playbook 'playbooks/site.yml', inventory 'acme-nodes', repository 'acme', environment 'empty'."
  exit 1
fi

echo "✅ Task template created. You have a one-click runnable job now."
exit 0
