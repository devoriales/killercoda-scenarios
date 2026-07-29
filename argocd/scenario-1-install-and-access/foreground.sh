#!/bin/bash
# The only thing the student sees while setup runs. It names each phase in plain
# English and never echoes the hidden setup work or its output.
steps=(
  "Waiting for the Kubernetes cluster"
  "Installing the argocd CLI"
  "Pre-pulling Argo CD images"
)
signals=(
  "/tmp/kc-step1"
  "/tmp/kc-step2"
  "/tmp/kc-step3"
)

echo ""
echo "  Preparing your cluster. This takes a minute or two."
echo "  The images are pulled up front so your own install is quick."
echo ""

for i in "${!signals[@]}"; do
  while [ ! -f "${signals[$i]}" ]; do
    printf "\r  ⏳  %s..." "${steps[$i]}"
    sleep 1
  done
  printf "\r  ✅  %-42s\n" "${steps[$i]}"
done

while [ ! -f /tmp/kc-ready ]; do sleep 1; done

echo ""
echo "  Ready. Argo CD is NOT installed yet, that is your job."
echo "  Read the introduction on the left, then click START."
echo ""
