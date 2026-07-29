#!/bin/bash
set -e

if ! kubectl get application demo -n argocd >/dev/null 2>&1; then
  echo "The 'demo' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/01-application/demo-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application demo -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)

if [ "$SYNC" = "Unknown" ]; then
  echo "Sync status is Unknown, so the controller could not compare the cluster against Git."
  echo "Fix it with: argocd app get demo --hard-refresh"
  exit 1
fi

if [ "$SYNC" != "Synced" ]; then
  echo "The Application exists but is not Synced yet (currently: ${SYNC:-unknown})."
  echo "Fix it with: argocd app sync demo"
  exit 1
fi

if ! kubectl get deploy demo -n demo >/dev/null 2>&1; then
  echo "The demo Deployment is not in the cluster."
  echo "Fix it with: argocd app sync demo"
  exit 1
fi

TRACK=$(kubectl get deploy demo -n demo \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
if [ -z "$TRACK" ]; then
  echo "The Deployment has no tracking-id annotation, so Argo CD does not consider it managed."
  echo "Re-run: argocd app sync demo"
  exit 1
fi

echo "Application synced, and the Deployment is tracked as: $TRACK"
exit 0
