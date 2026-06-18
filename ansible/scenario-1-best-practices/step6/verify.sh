#!/bin/bash
# Verify prod deployed with prod secrets, and that the dev password cannot open prod vault.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

# 1. The prod deploy rendered prod values on web1.
CONF=$(docker exec lab_web1 cat /etc/webapp/webapp.conf 2>/dev/null || true)
if ! echo "$CONF" | grep -q '^environment=prod'; then
  echo "web1 is not rendered for prod. Run:"
  echo "  ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml"
  exit 1
fi
if ! echo "$CONF" | grep -q 'db_password=prod-DB-pw-9z8y7x'; then
  echo "The prod secret is not present in the rendered config."
  echo "Run: ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml"
  exit 1
fi

# 2. Isolation: with ONLY the dev id available, the prod vault must NOT decrypt.
if ANSIBLE_VAULT_IDENTITY_LIST="dev@.vault_pass.dev" \
     ansible-vault view inventories/prod/group_vars/all/vault.yml >/dev/null 2>&1; then
  echo "FAIL: the dev password decrypted the PROD vault — isolation is broken."
  exit 1
fi

echo "Prod deployed with prod secrets, and the dev password cannot open the prod vault."
