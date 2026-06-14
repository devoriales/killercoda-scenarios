#!/bin/bash
# Verify namespace has goldilocks label and VPA objects were created
set -e

# Check namespace label
LABEL=$(kubectl get namespace metrics-app -o jsonpath='{.metadata.labels.goldilocks\.fairwinds\.com/enabled}' 2>/dev/null)
if [ "$LABEL" != "true" ]; then
  echo "FAIL: metrics-app namespace does not have goldilocks.fairwinds.com/enabled=true label (found: '$LABEL')"
  exit 1
fi

# Check VPA objects exist (allow up to 15s for controller to react)
for i in $(seq 1 5); do
  VPA_COUNT=$(kubectl get vpa -n metrics-app --no-headers 2>/dev/null | wc -l)
  if [ "$VPA_COUNT" -ge 2 ]; then
    echo "Namespace labeled, $VPA_COUNT VPA objects created by Goldilocks."
    exit 0
  fi
  sleep 3
done

echo "FAIL: Expected VPA objects in metrics-app after labeling, found $VPA_COUNT"
exit 1
