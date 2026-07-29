#!/bin/bash
set -e

if ! kubectl get application root -n argocd >/dev/null 2>&1; then
  echo "The 'root' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/04-app-of-apps/root-application.yaml"
  exit 1
fi

# The point of the step: a child Application nobody applied by hand.
if ! kubectl get application managed-web -n argocd >/dev/null 2>&1; then
  echo "The child Application 'managed-web' has not appeared yet."
  echo "root uses automated sync, so give it a moment: sleep 30 && kubectl get applications -n argocd"
  exit 1
fi

CHILD_SYNC=$(kubectl get application managed-web -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ "$CHILD_SYNC" != "Synced" ]; then
  echo "'managed-web' exists but is not Synced yet (currently: ${CHILD_SYNC:-unknown})."
  echo "Wait a few seconds, or run: argocd app sync managed-web"
  exit 1
fi

if ! kubectl get deploy web -n demo >/dev/null 2>&1; then
  echo "'managed-web' is Synced but its workload is missing from the demo namespace."
  echo "Check: kubectl get deploy -n demo"
  exit 1
fi

# And the original app must still own its own resources.
TRACK=$(kubectl get deploy demo -n demo \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
if ! echo "$TRACK" | grep -q '^demo:'; then
  echo "The demo Deployment is now tracked by something else: $TRACK"
  echo "Two Applications are claiming the same resource."
  exit 1
fi

echo "root created managed-web on its own, its workload is running, and demo still owns its own resources."
exit 0
