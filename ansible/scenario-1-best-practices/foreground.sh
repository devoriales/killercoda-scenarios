#!/bin/bash
steps=("Installing Ansible & tools" "Writing the Acme repository" "Initialising Git & secrets")
signals=("/tmp/kc-step1" "/tmp/kc-step2" "/tmp/kc-ready")

echo ""
echo "  Preparing your Ansible lab (~3 minutes)..."
echo ""

for i in "${!signals[@]}"; do
  while [ ! -f "${signals[$i]}" ]; do
    printf "\r  ⏳  %s..." "${steps[$i]}"
    sleep 1
  done
  printf "\r  ✅  %-45s\n" "${steps[$i]}"
done

echo ""
echo "  Lab ready!  The Acme repo is at /root/acme"
echo "  (The managed-node Docker image builds in the background — Step 2 starts it.)"
echo ""
