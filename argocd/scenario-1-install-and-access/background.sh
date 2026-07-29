#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# The goal is to make the student's own `kubectl apply` fast and reliable, without
# doing any of the work the scenario is teaching. So this pre-pulls the container
# images (about 500 MB, which would otherwise leave the student staring at
# ContainerCreating for minutes) and installs the argocd CLI, but it deliberately
# does NOT create the namespace or install Argo CD. Those are step 1.
#
# No `set -e`: a failed optional step should degrade the environment, not abort setup.

mkdir -p /var/log/killercoda
LOG=/var/log/killercoda/background.log
ARGOCD_VERSION="v3.4.5"

# ── Phase 1: cluster ready ────────────────────────────────────────────────────
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 3; done
# Single-node clusters keep the control-plane taint, which would leave every Argo CD
# pod Pending. Remove it so the student's install can actually schedule.
kubectl taint nodes --all node-role.kubernetes.io/control-plane- >>"$LOG" 2>&1 || true
touch /tmp/kc-step1

# ── Phase 2: argocd CLI ───────────────────────────────────────────────────────
curl -sSL -o /usr/local/bin/argocd \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" \
  >>"$LOG" 2>&1 || true
chmod +x /usr/local/bin/argocd 2>>"$LOG" || true
touch /tmp/kc-step2

# ── Phase 3: pre-pull the images ──────────────────────────────────────────────
# Pulled through the cluster's own runtime so they land in the node's image store.
for img in \
  "quay.io/argoproj/argocd:${ARGOCD_VERSION}" \
  "public.ecr.aws/docker/library/redis:8.2.3-alpine" \
  "ghcr.io/dexidp/dex:v2.45.0"
do
  crictl pull "$img" >>"$LOG" 2>&1 || true
done
touch /tmp/kc-step3

# Keep the manifest handy locally so step 1 works even if GitHub is slow or blocked.
curl -sSL -o /root/manifests/01-install/argocd-install.yaml \
  "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  >>"$LOG" 2>&1 || true

touch /tmp/kc-ready
