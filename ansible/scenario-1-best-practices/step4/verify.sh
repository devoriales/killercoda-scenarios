#!/bin/bash
# Verify the webapp role rendered the DEV config (with the dev secret) on web1.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

CONF=$(docker exec lab_web1 cat /etc/webapp/webapp.conf 2>/dev/null || true)
if [ -z "$CONF" ]; then
  echo "No rendered config on web1 yet. Run: ansible-playbook playbooks/site.yml"
  exit 1
fi

if ! echo "$CONF" | grep -q '^environment=dev'; then
  echo "web1 config is not rendered for the dev environment:"
  echo "$CONF"
  echo "Run: ansible-playbook playbooks/site.yml"
  exit 1
fi

if ! echo "$CONF" | grep -q 'db_password=dev-Sup3rSecret-DB-pw'; then
  echo "The dev secret is not present in the rendered config."
  echo "This means the dev vault did not decrypt. Is .vault_pass.dev present?"
  exit 1
fi

echo "Role rendered the dev config on web1, including the vault-sourced dev secret."
