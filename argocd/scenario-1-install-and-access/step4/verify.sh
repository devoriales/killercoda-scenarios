#!/bin/bash
set -e

# The rotation must have happened: the new password authenticates.
code=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' \
  -X POST https://localhost:8080/api/v1/session \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"Killercoda!2026"}' 2>/dev/null || true)

if [ "$code" != "200" ]; then
  echo "The new password does not authenticate (HTTP ${code:-no response})."
  echo "Rotate it with the argocd account update-password command in this step,"
  echo "and make sure the port-forward from step 3 is still running."
  exit 1
fi

# And the bootstrap secret must be gone.
if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
  echo "The new password works, but argocd-initial-admin-secret is still present."
  echo "It still holds the retired password in plaintext."
  echo "Fix it with: kubectl delete secret argocd-initial-admin-secret -n argocd"
  exit 1
fi

# The live credential should now be a bcrypt hash in argocd-secret.
hash=$(kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d 2>/dev/null || true)
case "$hash" in
  \$2a\$*|\$2b\$*|\$2y\$*) ;;
  *) echo "argocd-secret does not contain a bcrypt admin.password hash."
     echo "Re-run the rotation step."
     exit 1 ;;
esac

echo "Password rotated, old credential rejected, and the bootstrap secret cleaned up."
exit 0
