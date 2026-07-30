#!/bin/bash
set -e

# The point of this step is having looked, so verify the evidence still exists in the
# repo-server log rather than requiring the Application to be present.
ERRS=$(kubectl logs deploy/argocd-repo-server -n argocd --tail=1000 2>/dev/null | grep -c '"level":"error"' || true)
if [ "${ERRS:-0}" -lt 1 ]; then
  echo "The repo-server has logged no errors, so the broken Application never reached it."
  echo "Create it and give it about 25 seconds:"
  echo "  kubectl apply -f /root/manifests/02-logs/broken-repo.yaml"
  exit 1
fi

if ! kubectl logs deploy/argocd-repo-server -n argocd --tail=1000 2>/dev/null | grep -q 'GenerateManifest'; then
  echo "No GenerateManifest calls in the repo-server log, which is unexpected on a running install."
  exit 1
fi

if ! kubectl logs deploy/argocd-repo-server -n argocd --tail=1000 2>/dev/null | grep -q 'Repository not found'; then
  echo "The repo-server log has errors but none about a missing repository."
  echo "Apply the broken Application so the failure you are meant to read actually happens:"
  echo "  kubectl apply -f /root/manifests/02-logs/broken-repo.yaml"
  exit 1
fi

if kubectl get application broken-repo -n argocd >/dev/null 2>&1; then
  echo "Found the cause in the repo-server log. Clean up the broken Application to finish:"
  echo "  kubectl delete application broken-repo -n argocd"
  exit 1
fi

echo "Diagnosed and cleaned up: the repo-server named the cause via grpc.method=GenerateManifest, and the controller logged nothing."
exit 0
