#!/bin/bash
# Verify Goldilocks controller and dashboard are running with correct image
set -e

# Both pods must be Running
RUNNING=$(kubectl get pods -n goldilocks --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [ "$RUNNING" -lt 2 ]; then
  echo "Expected 2 Goldilocks pods Running, found $RUNNING"
  exit 1
fi

# Confirm correct registry (not deprecated quay.io)
IMAGE=$(kubectl get pods -n goldilocks -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null)
if echo "$IMAGE" | grep -q "quay.io"; then
  echo "ERROR: Goldilocks is using the deprecated quay.io registry: $IMAGE"
  exit 1
fi

if ! echo "$IMAGE" | grep -q "us-docker.pkg.dev"; then
  echo "WARNING: Unexpected image registry: $IMAGE"
fi

echo "Goldilocks installed: $RUNNING pods Running, image=$IMAGE"
