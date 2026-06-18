#!/bin/bash
# Ansible lab foreground.sh — readiness gate.
#
# Killercoda runs this automatically in the student's terminal and blocks Step 1 until it
# finishes. It waits for the background install (toolchain, assembled repo, encrypted
# vaults, built node image) and self-heals by re-running the idempotent /root/setup.sh if
# the background run aborted. The student never has to copy/paste a wait loop.
set -uo pipefail

TIMEOUT=480   # hard ceiling — apt + pip + ansible-galaxy + docker build can take a while
GRACE=90      # how long to wait before attempting a self-heal re-run
ELAPSED=0

encrypted() {
  head -n1 "$1" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'
}

ready() {
  command -v ansible    >/dev/null 2>&1 || return 1
  command -v ansible-vault >/dev/null 2>&1 || return 1
  command -v pre-commit >/dev/null 2>&1 || return 1
  [ -d /root/acme/.git ] || return 1
  encrypted /root/acme/inventories/dev/group_vars/all/vault.yml  || return 1
  encrypted /root/acme/inventories/prod/group_vars/all/vault.yml || return 1
  return 0
}

echo "Preparing the lab environment (installing Ansible, assembling the repo, building node image)..."

# Wait for background.sh to write the installer before we consider self-healing.
while [ ! -f /root/setup.sh ] && [ "$ELAPSED" -lt 60 ]; do
  sleep 2; ELAPSED=$((ELAPSED + 2))
done

while ! ready; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Environment not fully ready after ${TIMEOUT}s."
    echo "Inspect with: bash /root/setup.sh   (re-runs the idempotent installer)"
    break
  fi
  # Self-heal: past the grace period and still not ready → re-run the idempotent installer.
  if [ "$ELAPSED" -ge "$GRACE" ]; then
    echo "Setup looks incomplete — reconciling..."
    [ -f /root/setup.sh ] && bash /root/setup.sh
  fi
  echo "Waiting for environment... (${ELAPSED}s)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

if ready; then
  echo "Ready! The Acme Ansible repo is at /root/acme."
fi
