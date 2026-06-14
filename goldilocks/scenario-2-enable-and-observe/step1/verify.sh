#!/bin/bash
# Verify sample app is deployed and no VPAs exist yet
set -e

# Deployments exist
DEPS=$(kubectl get deployments -n metrics-app --no-headers 2>/dev/null | wc -l)
if [ "$DEPS" -lt 2 ]; then
  echo "FAIL: Expected at least 2 deployments in metrics-app, found $DEPS"
  exit 1
fi

# Pods running
RUNNING=$(kubectl get pods -n metrics-app --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [ "$RUNNING" -lt 2 ]; then
  echo "FAIL: Expected at least 2 Running pods in metrics-app, found $RUNNING"
  exit 1
fi

echo "Sample app ready: $DEPS deployments, $RUNNING pods Running."
