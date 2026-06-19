#!/bin/bash
set -e

INV=/root/lab/inventory/hosts.ini

if [ ! -f "$INV" ]; then
  echo "Inventory file not found at $INV"
  echo "Run: mkdir -p /root/lab/inventory && create hosts.ini (see step instructions)"
  exit 1
fi

if ! grep -q '^\[webservers\]' "$INV"; then
  echo "[webservers] group not found in $INV"
  exit 1
fi

if ! grep -q '^\[dbservers\]' "$INV"; then
  echo "[dbservers] group not found in $INV"
  exit 1
fi

for host in web1 web2; do
  if ! grep -q "^${host}[[:space:]]" "$INV"; then
    echo "$host not found in $INV"
    echo "Add it under [webservers] with ansible_host=localhost ansible_port=220X"
    exit 1
  fi
done

if ! grep -q '^db1[[:space:]]' "$INV"; then
  echo "db1 not found in $INV"
  echo "Add it under [dbservers] with ansible_host=localhost ansible_port=2203"
  exit 1
fi

echo "Inventory is correctly structured with webservers (web1, web2) and dbservers (db1)."
exit 0
