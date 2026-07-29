#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# Scenarios 1 and 2 covered installing Argo CD and building an Application, so this
# one starts with both done and gets straight to the four ways of deploying. This
# script does the whole install, waits for it to be usable, and pre-pulls the
# workload image so each sync completes in seconds rather than minutes.
#
# The CLI is put into core mode. Core mode talks to the Kubernetes API directly
# instead of to argocd-server, so there is no port-forward to keep alive and no
# password to paste. Every `argocd app ...` command behaves the same either way.
#
# No `set -e`: a failed optional step should degrade the environment, not abort setup.

mkdir -p /var/log/killercoda
LOG=/var/log/killercoda/background.log
ARGOCD_VERSION="v3.4.5"
HELM_VERSION="3.19.4"

# ── Write the progress script FIRST ───────────────────────────────────────────
# Killercoda pastes foreground.sh into the student's terminal line by line rather
# than executing it as a file, so anything inline there is echoed as if the
# student typed it. Keeping foreground.sh to four lines that just run this file
# means the student sees output only. This must be written before the slow work
# below, or foreground.sh sits waiting on a file that does not exist yet.
cat > /root/progress.sh <<'PROGRESS'
steps=(
  "Waiting for the Kubernetes cluster"
  "Installing the argocd and helm CLIs"
  "Installing Argo CD 3.4.5"
  "Waiting for Argo CD to be ready"
)
signals=(
  "/tmp/kc-step1"
  "/tmp/kc-step2"
  "/tmp/kc-step3"
  "/tmp/kc-step4"
)

echo ""
echo "  Setting up Argo CD for you. This takes two to three minutes."
echo "  Installing it was scenario 1. This one is about how you deploy with it."
echo ""

for i in "${!signals[@]}"; do
  printf "  ... %s\n" "${steps[$i]}"
  while [ ! -f "${signals[$i]}" ]; do sleep 2; done
  printf "  OK  %s\n" "${steps[$i]}"
done

while [ ! -f /tmp/kc-ready ]; do sleep 1; done

echo ""
echo "  Ready. Argo CD is running and the CLI is ready to use."
echo "  Read the introduction on the left, then click START."
echo ""
PROGRESS
chmod +x /root/progress.sh

# ── Phase 1: cluster ready ────────────────────────────────────────────────────
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 3; done
# Single-node clusters keep the control-plane taint, which would leave every Argo CD
# pod Pending forever.
kubectl taint nodes --all node-role.kubernetes.io/control-plane- >>"$LOG" 2>&1 || true
touch /tmp/kc-step1

# ── Phase 2: argocd and helm CLIs ─────────────────────────────────────────────
curl -sSL -o /usr/local/bin/argocd \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" \
  >>"$LOG" 2>&1 || true
chmod +x /usr/local/bin/argocd 2>>"$LOG" || true

# helm is needed for exactly one command in step 3: `helm list -n demo`, which
# returns nothing and is the whole point. Pinned to the version baked into the
# 3.4.5 repo-server image so the student's binary matches the one that renders.
if ! command -v helm >/dev/null 2>&1; then
  curl -sSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    -o /tmp/helm.tgz >>"$LOG" 2>&1 || true
  tar -xzf /tmp/helm.tgz -C /tmp >>"$LOG" 2>&1 || true
  install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm >>"$LOG" 2>&1 || true
  rm -rf /tmp/helm.tgz /tmp/linux-amd64 >>"$LOG" 2>&1 || true
fi
touch /tmp/kc-step2

# ── Phase 3: install Argo CD ──────────────────────────────────────────────────
# --server-side because the ApplicationSet CRD is about 374 KB and cannot fit in
# the 262144 byte annotation that client-side apply writes. That failure is what
# scenario 1 is about; here it would just be an obstacle.
kubectl create namespace argocd >>"$LOG" 2>&1 || true
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  >>"$LOG" 2>&1 || true
touch /tmp/kc-step3

# ── Phase 4: wait for it to be usable ─────────────────────────────────────────
# Retried rather than waited on once, because a single long watch dies with
# "client connection lost" while the node is busy pulling images, and reports a
# timeout over an install that is fine.
for _ in $(seq 1 40); do
  if kubectl wait --for=condition=Available --timeout=30s deployment --all -n argocd >>"$LOG" 2>&1; then
    break
  fi
  sleep 5
done
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=120s >>"$LOG" 2>&1 || true

# Core mode reads the namespace from the kubectl context, so point the context at
# argocd and turn core mode on for every argocd invocation.
kubectl config set-context --current --namespace=argocd >>"$LOG" 2>&1 || true
grep -q 'ARGOCD_OPTS' /root/.bashrc 2>/dev/null || echo "export ARGOCD_OPTS='--core'" >> /root/.bashrc
export ARGOCD_OPTS='--core'
touch /tmp/kc-step4

# Pre-pull the workload image so each of the four syncs goes Healthy quickly. Every
# deployment style in this scenario renders down to the same nginx image.
crictl pull docker.io/library/nginx:1.29-alpine >>"$LOG" 2>&1 || true

touch /tmp/kc-ready
