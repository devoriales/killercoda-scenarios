#!/bin/bash
# Verify the Git safety nets: encrypted vault committed, passwords ignored, guard rejects
# plaintext. Non-destructive — it does not touch the student's tracked files.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

# 1. The pre-commit hook is installed.
if [ ! -f .git/hooks/pre-commit ]; then
  echo "pre-commit is not installed. Run: pre-commit install"
  exit 1
fi

# 2. The encrypted vault is committed (and still encrypted in the committed tree).
if ! git show HEAD:inventories/dev/group_vars/all/vault.yml 2>/dev/null | head -n1 | grep -q '^\$ANSIBLE_VAULT'; then
  echo "An encrypted vault.yml is not committed. Did you restore it after the drill?"
  echo "Run: git checkout -- inventories/dev/group_vars/all/vault.yml"
  exit 1
fi

# 3. The vault password file is gitignored.
if ! git check-ignore -q .vault_pass.dev; then
  echo ".vault_pass.dev is NOT gitignored — that secret could be committed!"
  exit 1
fi

# 4. The vault-encryption guard rejects a plaintext vault file.
printf 'vault_db_password: leaked\n' > /tmp/plain_vault.yml
if bash scripts/check-vault-encrypted.sh /tmp/plain_vault.yml >/dev/null 2>&1; then
  echo "FAIL: the vault-encryption guard accepted a plaintext file."
  rm -f /tmp/plain_vault.yml
  exit 1
fi
rm -f /tmp/plain_vault.yml

echo "Git hygiene verified: encrypted vault committed, passwords ignored, guards reject plaintext."
