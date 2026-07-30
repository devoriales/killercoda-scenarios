#!/bin/bash
set -e

if ! kubectl get application owner-a -n argocd >/dev/null 2>&1; then
  echo "The owner-a Application does not exist."
  echo "Create both with:"
  echo "  kubectl apply -f /root/manifests/01-ownership/owner-a.yaml -f /root/manifests/01-ownership/owner-b.yaml"
  exit 1
fi

if ! kubectl get deploy web-dev -n contested >/dev/null 2>&1; then
  echo "No web-dev Deployment in the contested namespace yet, so neither Application has synced."
  echo "Sync them with: argocd app sync owner-a   then   argocd app sync owner-b"
  exit 1
fi

# The student must have seen the conflict, which means both apps synced at some point.
# The tracking-id proves a takeover happened rather than a single owner.
TRACK=$(kubectl get deploy web-dev -n contested -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
if [ -z "$TRACK" ]; then
  echo "The Deployment has no tracking-id annotation, so Argo CD did not create it."
  exit 1
fi

# End state: the duplicate is gone. That is the actual fix the step teaches.
if kubectl get application owner-b -n argocd >/dev/null 2>&1; then
  WARN=$(kubectl get application owner-a -n argocd -o jsonpath='{range .status.conditions[*]}{.type}{end}' 2>/dev/null)
  if echo "$WARN" | grep -q 'SharedResourceWarning'; then
    echo "Conflict confirmed: owner-a reports SharedResourceWarning and the Deployment is tracked by ${TRACK%%:*}."
    echo "Now apply the fix the step describes, which is removing the duplicate:"
    echo "  kubectl delete application owner-b -n argocd"
    exit 1
  fi
  echo "Both Applications still exist but no SharedResourceWarning has been recorded yet."
  echo "Sync them both so the conflict actually happens:"
  echo "  argocd app sync owner-a && argocd app sync owner-b"
  exit 1
fi

echo "Resolved: the duplicate Application is gone, and web-dev survived with a single owner (${TRACK%%:*})."
exit 0
