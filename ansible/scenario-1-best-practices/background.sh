#!/bin/bash
# Ansible lab background.sh — installs the toolchain, assembles the live Acme repo at
# /root/acme, encrypts the per-environment vaults, warms the managed-node image, and
# initialises Git with the pre-commit safety nets.
#
# The install body is written to /root/setup.sh (single source of truth) and run from
# there. foreground.sh re-runs /root/setup.sh if it detects an incomplete environment,
# so a transient failure here is recoverable rather than fatal. We deliberately do NOT
# use `set -e`: one failing command must never abort the rest of the setup.
set -uo pipefail

# Write the idempotent installer. The outer heredoc is quoted ('SETUP') so nothing
# expands here — the inner heredocs are written verbatim and run when setup.sh executes.
cat > /root/setup.sh <<'SETUP'
#!/bin/bash
# Idempotent installer for the Ansible best-practices lab. Safe to run multiple times.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- 1. Toolchain ---------------------------------------------------------------
if ! command -v ansible >/dev/null 2>&1; then
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y --no-install-recommends ansible git openssh-client python3-pip >/dev/null 2>&1 || true
fi
if ! docker compose version >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends docker-compose-plugin >/dev/null 2>&1 || true
fi
# pip tools (Ubuntu 24.04 is PEP-668 managed; --break-system-packages is fine in this sandbox)
pip3 install --break-system-packages --quiet ansible-lint pre-commit detect-secrets >/dev/null 2>&1 || true

# --- 2. Assemble the live repo --------------------------------------------------
if [ ! -d /root/acme ]; then
  mkdir -p /root/acme
  cp -r /root/manifests/acme/. /root/acme/ 2>/dev/null || true
fi
cd /root/acme || exit 1

# Restore the dotfiles that were shipped without a leading dot (so asset globbing copies them).
[ -f dot.gitignore ] && mv -f dot.gitignore .gitignore
[ -f pre-commit-config.yaml ] && mv -f pre-commit-config.yaml .pre-commit-config.yaml
chmod +x scripts/check-vault-encrypted.sh docker/entrypoint.sh 2>/dev/null || true

# --- 3. Vault passwords (throwaway lab values) ----------------------------------
[ -f .vault_pass.dev ]  || printf 'dev-lab-password'  > .vault_pass.dev
[ -f .vault_pass.prod ] || printf 'prod-lab-password' > .vault_pass.prod
chmod 600 .vault_pass.dev .vault_pass.prod

# --- 4. Encrypt the per-environment vaults, then drop the plaintext sources ------
for env in dev prod; do
  src="inventories/$env/group_vars/all/vault.SOURCE.yml"
  dst="inventories/$env/group_vars/all/vault.yml"
  if [ -f "$src" ] && [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    ansible-vault encrypt --encrypt-vault-id "$env" "$dst" >/dev/null 2>&1 || true
  fi
  rm -f "$src"
done

# --- 5. Lint config + collections + warm the managed-node image -----------------
# A lenient lint profile so `ansible-lint` in the verify step passes deterministically.
# offline: true keeps lint from reaching out to Galaxy on every run.
[ -f .ansible-lint ] || cat > .ansible-lint <<'LINT'
---
profile: min
offline: true
LINT
ansible-galaxy collection install -r requirements.yml >/dev/null 2>&1 || true
docker compose -f docker/docker-compose.yml build >/dev/null 2>&1 || true

# --- 6. Git repo + pre-commit safety nets (clean baseline) ----------------------
if [ ! -d .git ]; then
  git init -q
  git config user.email "dev@acme.test"
  git config user.name  "Acme Dev"
  detect-secrets scan > .secrets.baseline 2>/dev/null || echo '{}' > .secrets.baseline
  pre-commit install        >/dev/null 2>&1 || true
  pre-commit install-hooks  >/dev/null 2>&1 || true
  git add -A >/dev/null 2>&1 || true
  # --no-verify: the baseline commit must not be blocked by formatting hooks.
  git commit -q --no-verify -m "Initial Acme Ansible repo (encrypted vaults)" >/dev/null 2>&1 || true
fi

echo "[setup] Ansible lab repo ready at /root/acme."
SETUP

chmod +x /root/setup.sh
bash /root/setup.sh
echo "[background] Ansible lab ready."
