#!/bin/bash
# pre-commit guard: fail if any matched group_vars vault.yml is not Ansible-Vault
# encrypted. Stops a teammate from accidentally committing a plaintext secret.
set -e

status=0
for f in "$@"; do
  if ! head -n1 "$f" | grep -q '^\$ANSIBLE_VAULT'; then
    echo "ERROR: $f is NOT vault-encrypted — refusing to commit a plaintext secret."
    status=1
  fi
done
exit "$status"
