#!/bin/bash
set -e

# /tmp/node_info.txt must exist on web1 with expected content
CONTENT=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
     -i /root/.ssh/id_ed25519 -p 2201 ansible@localhost \
     "cat /tmp/node_info.txt 2>/dev/null" 2>/dev/null || true)

if [ -z "$CONTENT" ]; then
  echo "/tmp/node_info.txt not found on web1."
  echo "Run: cd /root/lab && ansible-playbook node-info.yml"
  exit 1
fi

if ! echo "$CONTENT" | grep -q "Hostname:"; then
  echo "/tmp/node_info.txt on web1 does not contain a Hostname field."
  exit 1
fi

if ! echo "$CONTENT" | grep -q "OS:"; then
  echo "/tmp/node_info.txt on web1 does not contain an OS field."
  exit 1
fi

# Check that group_vars/webservers.yml exists
if [ ! -f /root/lab/group_vars/webservers.yml ]; then
  echo "group_vars/webservers.yml not found."
  echo "Create it at /root/lab/group_vars/webservers.yml with app_port and app_name."
  exit 1
fi

echo "node_info.txt is present on web1 with correct content. group_vars are in place."
exit 0
