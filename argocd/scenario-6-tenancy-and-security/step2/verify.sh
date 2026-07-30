#!/bin/bash
set -e

# The local account must exist, which lives in argocd-cm not argocd-rbac-cm.
if [ "$(kubectl get cm argocd-cm -n argocd -o jsonpath='{.data.accounts\.developer}' 2>/dev/null)" = "" ]; then
  echo "The 'developer' account has not been created."
  echo "Fix it with:"
  echo "  kubectl patch cm argocd-cm -n argocd --type merge -p '{\"data\":{\"accounts.developer\":\"login\"}}'"
  exit 1
fi

POLICY=$(kubectl get cm argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.csv}' 2>/dev/null)
if [ -z "$POLICY" ]; then
  echo "argocd-rbac-cm has no policy.csv yet."
  echo "Apply the policy patch from the step, then restart argocd-server."
  exit 1
fi

# The scoped grant and the explicit deny must both be present.
echo "$POLICY" | grep -q "role:dev, applications, sync, tenant-a" || {
  echo "The policy does not grant role:dev sync on tenant-a. Re-apply the patch from the step."
  exit 1
}
echo "$POLICY" | grep -q "exec, create, tenant-a/\*, deny" || {
  echo "The policy does not deny exec on tenant-a."
  echo "exec opens a shell inside a running container, bypassing the project boundaries."
  exit 1
}

# The point of the step: policy.default closed, so reads do not leak across projects.
DEFAULT=$(kubectl get cm argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.default}' 2>/dev/null)
if [ -n "$DEFAULT" ]; then
  echo "policy.default is still set to '$DEFAULT', so every authenticated user can read every project."
  echo "That is the leak the step demonstrates. Close it with:"
  echo "  kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{\"data\":{\"policy.default\":\"\"}}'"
  echo "then restart argocd-server."
  exit 1
fi

# And prove enforcement through Argo CD's own evaluator rather than by reading the file.
CAN_SYNC=$(argocd admin settings rbac can developer sync applications 'tenant-a/anything' --namespace argocd 2>/dev/null | tr -d '\r\n ')
CAN_READ_OTHER=$(argocd admin settings rbac can developer get applications 'tenant-b/anything' --namespace argocd 2>/dev/null | tr -d '\r\n ')

if [ "$CAN_SYNC" != "Yes" ]; then
  echo "developer cannot sync in tenant-a (evaluator says: '${CAN_SYNC:-unknown}')."
  echo "Did argocd-server restart after the policy patch?"
  exit 1
fi
if [ "$CAN_READ_OTHER" = "Yes" ]; then
  echo "developer can still read tenant-b, so the cross-project read leak is still open."
  echo "Confirm policy.default is empty and that argocd-server has been restarted."
  exit 1
fi

echo "Scoped policy enforced: developer may sync tenant-a, may not delete it, and can no longer read tenant-b."
exit 0
