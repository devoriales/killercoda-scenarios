#!/bin/bash
# Verify the inventory graph exposes the expected groups and hosts.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

GRAPH=$(ansible-inventory --graph 2>/dev/null || true)

for token in webservers dbservers web1 web2 db1; do
  if ! echo "$GRAPH" | grep -q "$token"; then
    echo "Inventory graph is missing '$token'."
    echo "Run: ansible-inventory --graph"
    exit 1
  fi
done

echo "Inventory groups resolve correctly: webservers (web1, web2) and dbservers (db1)."
