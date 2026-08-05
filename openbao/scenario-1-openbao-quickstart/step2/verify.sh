#!/bin/bash
set -e

if [ ! -f /root/init.json ]; then
  echo "No initialization output found at /root/init.json."
  echo "Initialize with: bao operator init -key-shares=3 -key-threshold=2 -format=json | tee /root/init.json"
  exit 1
fi

STATUS=$(kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 bao status -format=json 2>/dev/null || true)
if [ -z "$STATUS" ]; then
  echo "Could not read the seal status from the pod."
  echo "Check the pod is running with: kubectl get pods -n openbao"
  exit 1
fi

INITIALIZED=$(echo "$STATUS" | jq -r '.initialized')
SEALED=$(echo "$STATUS" | jq -r '.sealed')

if [ "$INITIALIZED" != "true" ]; then
  echo "OpenBao is not initialized yet."
  echo "Initialize with: bao operator init -key-shares=3 -key-threshold=2 -format=json | tee /root/init.json"
  exit 1
fi

if [ "$SEALED" != "false" ]; then
  PROGRESS=$(echo "$STATUS" | jq -r '.progress')
  THRESHOLD=$(echo "$STATUS" | jq -r '.t')
  echo "OpenBao is still sealed (${PROGRESS}/${THRESHOLD} shares provided)."
  echo "Supply another share with: bao operator unseal \$(jq -r '.unseal_keys_b64[1]' /root/init.json)"
  exit 1
fi

READY=$(kubectl get pod openbao-0 -n openbao -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)
if [ "$READY" != "true" ]; then
  echo "OpenBao is unsealed, but the pod has not reported Ready yet."
  echo "The readiness probe runs every few seconds. Wait a moment and check again."
  exit 1
fi

echo "Initialized, unsealed, and the pod is Ready. The root key is in memory."
exit 0
