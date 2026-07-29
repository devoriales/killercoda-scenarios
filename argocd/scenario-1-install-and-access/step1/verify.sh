#!/bin/bash
set -e

if ! kubectl get ns argocd >/dev/null 2>&1; then
  echo "The argocd namespace does not exist yet."
  echo "Fix it with: kubectl create namespace argocd"
  exit 1
fi

# The whole point of the step: the ApplicationSet CRD must be present and established,
# which only happens after the server-side apply.
if ! kubectl get crd applicationsets.argoproj.io >/dev/null 2>&1; then
  echo "The applicationsets.argoproj.io CRD is missing."
  echo "That is the object client-side apply could not write."
  echo "Fix it with: kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.5/manifests/install.yaml"
  exit 1
fi

if ! kubectl get crd applicationsets.argoproj.io \
     -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null | grep -q True; then
  echo "The applicationsets CRD exists but is not Established yet. Wait a few seconds and check again."
  exit 1
fi

for crd in applications.argoproj.io appprojects.argoproj.io; do
  if ! kubectl get crd "$crd" >/dev/null 2>&1; then
    echo "Missing CRD: $crd. Re-run the server-side apply."
    exit 1
  fi
done

echo "All three Argo CD CRDs are installed, including the one client-side apply could not write."
exit 0
