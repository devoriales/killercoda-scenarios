#!/bin/bash
set -e

if ! kubectl get applicationset git-demo -n argocd >/dev/null 2>&1; then
  echo "The 'git-demo' ApplicationSet does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/02-discover/appset-git.yaml"
  exit 1
fi

MISSING=""
for env in dev staging prod; do
  kubectl get application "git-$env" -n argocd >/dev/null 2>&1 || MISSING="$MISSING git-$env"
done
if [ -n "$MISSING" ]; then
  echo "The Git generator has not discovered these yet:$MISSING"
  echo "It scans the repository, so give it a few seconds and check again."
  exit 1
fi

if ! kubectl get applicationset cluster-demo -n argocd >/dev/null 2>&1; then
  echo "The 'cluster-demo' ApplicationSet does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/02-discover/appset-cluster.yaml"
  exit 1
fi

# The observation the step rests on: clusters:{} generates in-cluster even with
# zero cluster secrets registered.
if ! kubectl get application cl-in-cluster -n argocd >/dev/null 2>&1; then
  echo "Expected the clusters generator to produce 'cl-in-cluster'."
  echo "The cluster Argo CD runs in is always a target, even with no cluster secrets."
  echo "Give it a few seconds, then: kubectl get applications -n argocd | grep cl-"
  exit 1
fi

echo "Git discovered three environments from folder names, and clusters:{} produced cl-in-cluster from zero secrets."
exit 0
