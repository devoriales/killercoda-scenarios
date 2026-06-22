#!/bin/bash
set -e
. /root/.lab/api.sh

sem_login
PID="$(sem_pid)"
if [ -z "$PID" ] || [ "$PID" = "null" ]; then
  echo "Could not find the 'Acme Automation' project. Is Semaphore still up? (curl -s http://127.0.0.1:3000/api/ping)"
  exit 1
fi

count="$(sem_get "/project/$PID/inventory" | jq 'length' 2>/dev/null || echo 0)"
if [ "${count:-0}" -lt 1 ]; then
  echo "No inventory found in the project yet."
  echo "In the UI: Inventory → New Inventory → Type 'File', Repository 'acme', file 'inventory/hosts.yml'."
  exit 1
fi

echo "✅ Inventory created. Semaphore now knows which hosts to target."
exit 0
