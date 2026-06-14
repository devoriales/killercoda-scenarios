#!/bin/bash
# Scenario 1 background.sh — installs Helm + metrics-server before student arrives
set -euo pipefail

# Wait for cluster to be ready
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 3; done

# Install Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --no-sudo 2>/dev/null

# Add Helm repos
helm repo add fairwinds-stable https://charts.fairwinds.com/stable 2>/dev/null || true
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update 2>/dev/null

# Install metrics-server (required by VPA recommender)
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args[0]=--kubelet-insecure-tls' \
  --wait --timeout 120s 2>/dev/null || true

echo "[background] Ready."
