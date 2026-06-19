#!/bin/bash
set -e

if [ ! -f /root/lab/ansible.cfg ]; then
  echo "ansible.cfg not found at /root/lab/ansible.cfg"
  echo "Create it with: mkdir -p /root/lab && cat > /root/lab/ansible.cfg (see step instructions)"
  exit 1
fi

if ! grep -qE '^\s*inventory\s*=' /root/lab/ansible.cfg; then
  echo "ansible.cfg is missing an 'inventory =' line under [defaults]"
  exit 1
fi

if ! grep -qE '^\s*remote_user\s*=' /root/lab/ansible.cfg; then
  echo "ansible.cfg is missing a 'remote_user =' line under [defaults]"
  exit 1
fi

if ! grep -qE '^\s*private_key_file\s*=' /root/lab/ansible.cfg; then
  echo "ansible.cfg is missing a 'private_key_file =' line under [defaults]"
  exit 1
fi

echo "ansible.cfg is present and correctly configured."
exit 0
