#!/bin/bash
# Final verification: VPA + Goldilocks + service + helm releases
set -e

# VPA: 3 pods running
VPA_RUNNING=$(kubectl get pods -n vpa --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [ "$VPA_RUNNING" -lt 3 ]; then
  echo "FAIL: Expected 3 VPA pods Running, found $VPA_RUNNING"
  exit 1
fi

# Goldilocks: 2 pods running
GLD_RUNNING=$(kubectl get pods -n goldilocks --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [ "$GLD_RUNNING" -lt 2 ]; then
  echo "FAIL: Expected 2 Goldilocks pods Running, found $GLD_RUNNING"
  exit 1
fi

# Dashboard service exists
if ! kubectl get svc goldilocks-dashboard -n goldilocks &>/dev/null; then
  echo "FAIL: goldilocks-dashboard service not found"
  exit 1
fi

# Helm releases deployed
VPA_STATUS=$(helm list -n vpa -o json 2>/dev/null | python3 -c "import json,sys; releases=json.load(sys.stdin); print(releases[0]['status'] if releases else 'missing')" 2>/dev/null || echo "missing")
GLD_STATUS=$(helm list -n goldilocks -o json 2>/dev/null | python3 -c "import json,sys; releases=json.load(sys.stdin); print(releases[0]['status'] if releases else 'missing')" 2>/dev/null || echo "missing")

if [ "$VPA_STATUS" != "deployed" ]; then
  echo "FAIL: VPA Helm release status is '$VPA_STATUS', expected 'deployed'"
  exit 1
fi
if [ "$GLD_STATUS" != "deployed" ]; then
  echo "FAIL: Goldilocks Helm release status is '$GLD_STATUS', expected 'deployed'"
  exit 1
fi

echo "All checks passed: VPA ($VPA_RUNNING pods), Goldilocks ($GLD_RUNNING pods), dashboard service present, both Helm releases deployed."
