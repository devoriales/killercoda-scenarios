#!/bin/bash
set -e

running="$(docker ps --filter name=lab_ --filter status=running --format '{{.Names}}')"
for n in lab_web1 lab_web2 lab_db1; do
  if ! echo "$running" | grep -q "^${n}$"; then
    echo "Node ${n#lab_} is not running. Bring the nodes up with:"
    echo "  bash /root/lab/docker/up.sh"
    exit 1
  fi
done

echo "✅ web1, web2 and db1 are running and ready for Ansible."
exit 0
