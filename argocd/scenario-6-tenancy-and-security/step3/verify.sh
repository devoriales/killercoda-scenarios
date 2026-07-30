#!/bin/bash
set -e

# Gate one.
NS=$(kubectl get cm argocd-cmd-params-cm -n argocd -o jsonpath='{.data.application\.namespaces}' 2>/dev/null)
if [ -z "$NS" ]; then
  echo "application.namespaces is not set, so the controller does not watch tenant namespaces."
  echo "Fix it with:"
  echo "  kubectl patch cm argocd-cmd-params-cm -n argocd --type merge -p '{\"data\":{\"application.namespaces\":\"tenant-*\"}}'"
  echo "then restart the application controller and argocd-server."
  exit 1
fi

# Gate two.
SRC=$(kubectl get appproject tenant-a -n argocd -o jsonpath='{.spec.sourceNamespaces[*]}' 2>/dev/null)
if ! echo "$SRC" | grep -q 'tenant-a'; then
  echo "The tenant-a project does not list tenant-a in sourceNamespaces (found: '${SRC:-none}')."
  echo "Fix it with:"
  echo "  kubectl patch appproject tenant-a -n argocd --type merge -p '{\"spec\":{\"sourceNamespaces\":[\"tenant-a\"]}}'"
  exit 1
fi

if ! kubectl get application tenant-owned -n tenant-a >/dev/null 2>&1; then
  echo "The 'tenant-owned' Application does not exist in the tenant-a namespace."
  echo "Fix it with: kubectl apply -f /root/manifests/03-namespaces/tenant-app.yaml"
  exit 1
fi

# The point of the step: it is now actually being reconciled, which means it has a
# sync status at all. Silence is the failure this step exists to show.
SYNC=$(kubectl get application tenant-owned -n tenant-a -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ -z "$SYNC" ]; then
  echo "The Application still has NO sync status, so the controller is not reconciling it."
  echo "Both gates are set, so the likely cause is that the controller has not restarted yet."
  echo "Check with: kubectl rollout status statefulset argocd-application-controller -n argocd"
  exit 1
fi

# And the project rejection must be gone.
MSG=$(kubectl get application tenant-owned -n tenant-a -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)
if echo "$MSG" | grep -q "is not permitted to use project"; then
  echo "The Application still reports: $MSG"
  echo "Both gates are set, so this is almost certainly a STALE condition: editing an"
  echo "AppProject does not re-queue the Applications under it, so the message you are"
  echo "reading was written before your patch."
  echo "Force a re-evaluation with:"
  echo "  kubectl annotate application tenant-owned -n tenant-a argocd.argoproj.io/refresh=hard --overwrite"
  exit 1
fi

echo "Both gates open: the controller watches tenant-a, the project accepts it, and the Application reports sync status $SYNC."
exit 0
