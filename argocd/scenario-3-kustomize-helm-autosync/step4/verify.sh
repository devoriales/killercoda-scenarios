#!/bin/bash
set -e

if ! kubectl get application autosync -n argocd >/dev/null 2>&1; then
  echo "The 'autosync' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/04-autosync/autosync-application.yaml"
  exit 1
fi

# The policy itself must be on, since the whole step depends on it.
SELFHEAL=$(kubectl get application autosync -n argocd \
  -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null)
if [ "$SELFHEAL" != "true" ]; then
  echo "selfHeal is not enabled on the autosync Application."
  echo "Re-apply it: kubectl apply -f /root/manifests/04-autosync/autosync-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application autosync -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ "$SYNC" != "Synced" ]; then
  echo "'autosync' is not Synced yet (currently: ${SYNC:-unknown})."
  echo "It syncs itself, so give it a moment: sleep 30 && kubectl get application autosync -n argocd"
  exit 1
fi

if ! kubectl get deploy autosync -n demo >/dev/null 2>&1; then
  echo "The autosync Deployment is missing from the demo namespace."
  echo "Wait for the automated sync, or check: argocd app get autosync"
  exit 1
fi

# The point of the step: whatever the student scaled it to, Git wins in the end.
REPLICAS=$(kubectl get deploy autosync -n demo -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$REPLICAS" != "1" ]; then
  echo "The Deployment currently has $REPLICAS replicas, but Git declares 1."
  echo "selfHeal reverts within about 5 to 15 seconds. Watch it happen:"
  echo "  kubectl get deploy autosync -n demo -o jsonpath='{.spec.replicas}'"
  exit 1
fi

echo "Back to 1 replica, matching Git, with nobody reverting it by hand."
exit 0
