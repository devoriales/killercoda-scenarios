#!/bin/bash
steps=("Installing Ansible" "Building managed-node image" "Starting web1, web2, db1" "Configuring SSH access")
signals=("/tmp/kc-step1" "/tmp/kc-step2" "/tmp/kc-step3" "/tmp/kc-ready")

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
echo "  Lab ready!  Your workspace is at /root/lab"
echo ""
