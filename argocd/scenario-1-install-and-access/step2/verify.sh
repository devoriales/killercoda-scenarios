#!/bin/bash
set -e

expected="argocd-application-controller argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis argocd-repo-server argocd-server"

for w in $expected; do
  if ! kubectl get pods -n argocd -o name 2>/dev/null | grep -q "$w"; then
    echo "Workload not found: $w"
    echo "Re-run the server-side apply from step 1, then wait for the rollout."
    exit 1
  fi
done

running=$(kubectl get pods -n argocd --no-headers 2>/dev/null | awk '$3=="Running"' | wc -l | tr -d ' ')
total=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$running" -lt 7 ]; then
  echo "Only ${running} of ${total} pods are Running; 7 are expected."
  echo "Check with: kubectl get pods -n argocd"
  echo "If any show Evicted, the node is short on disk rather than Argo CD being broken."
  exit 1
fi

# The version actually running, not the one in the URL.
img=$(kubectl get deploy argocd-server -n argocd \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
case "$img" in
  *:v3.4.5) ;;
  *) echo "argocd-server is running '${img}', expected quay.io/argoproj/argocd:v3.4.5"
     exit 1 ;;
esac

echo "Seven workloads Running on v3.4.5, and you checked the pods rather than trusting kubectl wait."
exit 0
