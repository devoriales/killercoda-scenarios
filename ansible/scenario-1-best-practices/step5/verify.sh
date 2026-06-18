#!/bin/bash
# Verify the dev vault is encrypted and decryptable with the dev password.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

VAULT=inventories/dev/group_vars/all/vault.yml

if ! head -n1 "$VAULT" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
  echo "$VAULT is not Ansible-Vault encrypted."
  echo "Check: head -n1 $VAULT"
  exit 1
fi

if ! ansible-vault view "$VAULT" 2>/dev/null | grep -q 'vault_db_password'; then
  echo "Could not decrypt the dev vault. Is .vault_pass.dev present and correct?"
  echo "Re-create it: printf 'dev-lab-password' > .vault_pass.dev && chmod 600 .vault_pass.dev"
  exit 1
fi

echo "Dev vault is encrypted (AES256) and decrypts with the dev password."
