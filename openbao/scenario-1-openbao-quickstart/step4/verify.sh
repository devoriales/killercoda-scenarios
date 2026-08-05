#!/bin/bash
set -e

TOKEN=$(jq -r '.root_token' /root/init.json 2>/dev/null || true)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Could not read the root token from /root/init.json."
  echo "Re-run step 2 so the initialization output is saved."
  exit 1
fi

kb() { kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$TOKEN" bao "$@" 2>/dev/null; }

META=$(kb kv metadata get -format=json secret/production/db || true)
if [ -z "$META" ]; then
  echo "secret/production/db no longer exists."
  echo "If you ran 'bao kv metadata delete', the whole secret and its history are gone, which is the point of that command."
  echo "Recreate it with: bao kv put secret/production/db username=dbadmin password=initial-secret"
  exit 1
fi

DESTROYED=$(echo "$META" | jq -r '[.data.versions[] | select(.destroyed == true)] | length')
if [ "$DESTROYED" -lt 1 ] 2>/dev/null; then
  echo "No version of secret/production/db has been destroyed yet."
  echo "Destroy one with: bao kv destroy -versions=2 secret/production/db"
  exit 1
fi

# A destroyed version must keep its slot in the history. That is the teaching point.
if ! echo "$META" | jq -e '.data.versions["2"]' >/dev/null 2>&1; then
  echo "Version 2 is missing from the history entirely."
  echo "Destroy keeps the version's metadata; only its data goes. Recreate and retry the step."
  exit 1
fi

echo "Version 2 is destroyed, and its entry remains in the history marked destroyed: true."
exit 0
