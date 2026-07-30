#!/bin/bash
set -e

if ! kubectl get application policies -n argocd >/dev/null 2>&1; then
  echo "The 'policies' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/03-policies/policies-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application policies -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ "$SYNC" != "Synced" ]; then
  echo "The Application is not Synced yet (currently: ${SYNC:-unknown})."
  echo "Fix it with: argocd app sync policies"
  exit 1
fi

# The two Jobs WITHOUT HookSucceeded must still be present, because that is the
# observation the whole step rests on: no policy behaves like BeforeHookCreation.
for j in policies-nopolicy policies-beforecreation; do
  if ! kubectl get job "$j" -n demo >/dev/null 2>&1; then
    echo "Expected $j to still exist after the sync."
    echo "Only HookSucceeded removes a hook immediately, so this one should have survived."
    echo "Re-run: argocd app sync policies"
    exit 1
  fi
done

# And the HookSucceeded one must be gone, which is the contrast.
if kubectl get job policies-succeeded -n demo >/dev/null 2>&1; then
  COMPLETED=$(kubectl get job policies-succeeded -n demo -o jsonpath='{.status.completionTime}' 2>/dev/null)
  if [ -n "$COMPLETED" ]; then
    echo "policies-succeeded still exists even though it completed."
    echo "HookSucceeded should have deleted it during the sync. Give it a few seconds and check again."
    exit 1
  fi
  echo "policies-succeeded is still running. Wait for it to finish and check again."
  exit 1
fi

echo "HookSucceeded removed its Job immediately, while the unannotated hook survived exactly like BeforeHookCreation."
exit 0
