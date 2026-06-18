#!/bin/bash
# Verify the three node containers are up and reachable over SSH via Ansible.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -cE '^lab_(web1|web2|db1)$' || true)
if [ "$RUNNING" -lt 3 ]; then
  echo "Expected 3 node containers running, found $RUNNING."
  echo "Run: bash docker/up.sh"
  exit 1
fi

if ! ansible all -m ping >/tmp/ansible_ping.out 2>&1; then
  echo "ansible could not reach all nodes:"
  cat /tmp/ansible_ping.out
  echo "Did you generate .ssh/lab_dev_ed25519 BEFORE running 'bash docker/up.sh'?"
  exit 1
fi

PONGS=$(grep -c '"ping": "pong"' /tmp/ansible_ping.out || true)
if [ "$PONGS" -lt 3 ]; then
  echo "Fewer than 3 nodes responded with pong:"
  cat /tmp/ansible_ping.out
  exit 1
fi

echo "All three nodes (web1, web2, db1) are reachable over SSH."
