#!/bin/bash
# Verify VPA pods are running and CRDs exist
set -e

# Check all three VPA pods are Running
RUNNING=$(kubectl get pods -n vpa --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [ "$RUNNING" -lt 3 ]; then
  echo "Expected 3 VPA pods Running, found $RUNNING"
  exit 1
fi

# Check VPA CRDs
if ! kubectl get crd verticalpodautoscalers.autoscaling.k8s.io &>/dev/null; then
  echo "VPA CRD not found"
  exit 1
fi

echo "VPA installed correctly: $RUNNING pods Running, CRDs present"
