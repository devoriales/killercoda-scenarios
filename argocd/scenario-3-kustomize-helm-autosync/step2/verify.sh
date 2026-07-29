#!/bin/bash
set -e

for app in kustom-dev kustom-prod; do
  if ! kubectl get application "$app" -n argocd >/dev/null 2>&1; then
    echo "The '$app' Application does not exist yet."
    echo "Fix it with: kubectl apply -f /root/manifests/02-kustomize/${app}-application.yaml"
    exit 1
  fi
  SYNC=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  if [ "$SYNC" != "Synced" ]; then
    echo "'$app' is not Synced yet (currently: ${SYNC:-unknown})."
    echo "Fix it with: argocd app sync kustom-dev kustom-prod"
    exit 1
  fi
done

# The point of the step: same base, different replica counts, proving the overlay patched.
DEV=$(kubectl get deploy dev-kustom -n demo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
PROD=$(kubectl get deploy prod-kustom -n demo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")

if [ -z "$DEV" ] || [ -z "$PROD" ]; then
  echo "Expected both dev-kustom and prod-kustom Deployments in the demo namespace."
  echo "Check: kubectl get deploy -n demo"
  exit 1
fi

if [ "$DEV" != "1" ]; then
  echo "dev-kustom should have 1 replica but has $DEV."
  exit 1
fi

if [ "$PROD" != "3" ]; then
  echo "prod-kustom should have 3 replicas but has $PROD."
  echo "If it has 1, the overlay patch matched nothing. Check: argocd app manifests kustom-prod"
  exit 1
fi

echo "One base, two overlays: dev-kustom has $DEV replica, prod-kustom has $PROD."
exit 0
