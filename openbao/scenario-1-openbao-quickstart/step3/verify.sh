#!/bin/bash
set -e

TOKEN=$(jq -r '.root_token' /root/init.json 2>/dev/null || true)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Could not read the root token from /root/init.json."
  echo "Re-run step 2 so the initialization output is saved."
  exit 1
fi

kb() { kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$TOKEN" bao "$@" 2>/dev/null; }

if ! kb secrets list -format=json | jq -e '."secret/"' >/dev/null 2>&1; then
  echo "No K/V v2 engine is mounted at secret/."
  echo "Enable it with: bao secrets enable -path=secret -version=2 kv"
  exit 1
fi

META=$(kb kv metadata get -format=json secret/production/db || true)
if [ -z "$META" ]; then
  echo "No secret found at secret/production/db."
  echo "Write one with: bao kv put secret/production/db username=dbadmin password=initial-secret"
  exit 1
fi

CURRENT=$(echo "$META" | jq -r '.data.current_version')
if [ "$CURRENT" -lt 2 ] 2>/dev/null; then
  echo "secret/production/db exists but has only version ${CURRENT}."
  echo "Write it again to create a second version: bao kv put secret/production/db username=dbadmin password=rotated-once"
  exit 1
fi

# The point of the step is that the older version is still readable.
if ! kb kv get -version=1 -format=json secret/production/db | jq -e '.data.data.password' >/dev/null 2>&1; then
  echo "Version 1 of secret/production/db is not readable."
  echo "It should be. Re-create the secret and rotate it with: bao kv put secret/production/db username=dbadmin password=initial-secret"
  exit 1
fi

echo "K/V v2 mounted, ${CURRENT} versions written, and version 1 is still readable."
exit 0
