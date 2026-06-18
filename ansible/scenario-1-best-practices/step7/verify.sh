#!/bin/bash
# Verify dev2's public key was authorized on the nodes by bootstrap.yml.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

if [ ! -f .ssh/dev2.pub ]; then
  echo "dev2's public key is not staged. Run:"
  echo "  cp /tmp/dev2_key.pub .ssh/dev2.pub"
  exit 1
fi

# Match the key material (field 2) so we prove THIS key was authorized, not just that
# some keys exist (the entrypoint already authorized the first dev at container start).
DEV2_KEY=$(cut -d' ' -f2 .ssh/dev2.pub)

if ! docker exec lab_web1 cat /home/ansible/.ssh/authorized_keys 2>/dev/null | grep -qF "$DEV2_KEY"; then
  echo "dev2's key is not yet authorized on web1."
  echo "Run: ansible-playbook playbooks/bootstrap.yml"
  exit 1
fi

echo "dev2's key is authorized on web1 — bootstrap.yml onboarded the second developer."
