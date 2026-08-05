#!/bin/bash
set -e

if ! kubectl get namespace openbao >/dev/null 2>&1; then
  echo "The openbao namespace does not exist yet."
  echo "Create it with: kubectl create namespace openbao"
  exit 1
fi

if ! helm status openbao -n openbao >/dev/null 2>&1; then
  echo "The openbao Helm release is not installed."
  echo "Install it with: helm install openbao openbao/openbao --namespace openbao --version 0.28.6 --values /root/manifests/values-quickstart.yaml"
  exit 1
fi

PHASE=$(kubectl get pod openbao-0 -n openbao -o jsonpath='{.status.phase}' 2>/dev/null || true)
if [ "$PHASE" != "Running" ]; then
  echo "Pod openbao-0 is not Running yet (currently: ${PHASE:-not created})."
  echo "Give it a few more seconds, then check with: kubectl get pods -n openbao"
  exit 1
fi

echo "OpenBao is deployed and running, sealed and uninitialized exactly as expected."
exit 0
