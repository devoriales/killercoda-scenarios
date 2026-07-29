#!/bin/bash
set -e

if ! kubectl get application plain -n argocd >/dev/null 2>&1; then
  echo "The 'plain' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/01-plain/plain-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application plain -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)

if [ "$SYNC" = "Unknown" ]; then
  echo "Sync status is Unknown, so the controller could not compare the cluster against Git."
  echo "Fix it with: argocd app get plain --hard-refresh"
  exit 1
fi

if [ "$SYNC" != "Synced" ]; then
  echo "The Application is not Synced yet (currently: ${SYNC:-unknown})."
  echo "Fix it with: argocd app sync plain"
  exit 1
fi

# The kind ordering claim: the Namespace had to exist for the rest to apply.
if ! kubectl get ns demo >/dev/null 2>&1; then
  echo "The demo namespace is missing, so the sync did not complete."
  echo "Fix it with: argocd app sync plain"
  exit 1
fi

for kind in deploy/demo svc/demo; do
  if ! kubectl get "$kind" -n demo >/dev/null 2>&1; then
    echo "Missing $kind in the demo namespace. Re-run: argocd app sync plain"
    exit 1
  fi
done

echo "One directory produced a Namespace, a Service and a Deployment, in that order."
exit 0
