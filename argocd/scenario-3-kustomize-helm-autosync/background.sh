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
# argocd. kubeconfig is read per command, so this applies to the shell the student
# already has open.
kubectl config set-context --current --namespace=argocd >>"$LOG" 2>&1 || true
# The CLI is wrapped rather than driven by ARGOCD_OPTS. The student's shell is
# spawned before this script finishes, so anything appended to .bashrc here is
# never sourced by the terminal they are actually typing into. A wrapper on PATH
# works in every shell, including the one already open.
mv /usr/local/bin/argocd /usr/local/bin/argocd-real 2>>"$LOG" || true
cat > /usr/local/bin/argocd <<'WRAP'
#!/bin/bash
# Argo CD CLI in core mode: talks to the Kubernetes API directly, so there is no
# argocd-server address to configure and no password to paste.
exec /usr/local/bin/argocd-real --core "$@"
WRAP
chmod +x /usr/local/bin/argocd 2>>"$LOG" || true
touch /tmp/kc-step4

# Pre-pull the workload image so each of the four syncs goes Healthy quickly. Every
# deployment style in this scenario renders down to the same nginx image.
crictl pull docker.io/library/nginx:1.29-alpine >>"$LOG" 2>&1 || true

# Write the manifests the steps reference. Killercoda's `assets` block did not
# deliver them (the target directory simply did not exist), and background.sh is
# the mechanism this repo already relies on for files the student must apply.
mkdir -p /root/manifests/01-plain
cat > /root/manifests/01-plain/plain-application.yaml <<'YAML_EOF'
# A plain-YAML Application. No Kustomize, no Helm, no configuration telling Argo CD
# which is which: it reads the directory and applies what it finds.
#
# The directory, not a file list, is the unit. Adding a manifest to that folder in
# Git is enough to have it deployed on the next sync.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: plain
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-03-core-concepts/01-application-crd/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/02-kustomize
cat > /root/manifests/02-kustomize/kustom-dev-application.yaml <<'YAML_EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustom-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-04-deploying-applications/02-kustomize/overlays/dev

  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/02-kustomize
cat > /root/manifests/02-kustomize/kustom-prod-application.yaml <<'YAML_EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustom-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-04-deploying-applications/02-kustomize/overlays/prod

  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/03-helm
cat > /root/manifests/03-helm/helm-demo-application.yaml <<'YAML_EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-04-deploying-applications/03-helm/demo-chart
    helm:
      # Argo CD does not run 'helm install'. It runs 'helm template' in the repo-server
      # and applies the output, so there is no Helm release and 'helm list' shows nothing.
      valuesObject:
        replicaCount: 2
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/04-autosync
cat > /root/manifests/04-autosync/autosync-application.yaml <<'YAML_EOF'
# Everything up to now needed an explicit sync. This one does not, and it also puts back
# anything you change by hand.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: autosync
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    # Its own manifests. Two Applications must never manage the same resources:
    # the second one takes ownership and the first goes OutOfSync against resources
    # it no longer controls, with nothing in the UI naming the cause.
    path: module-04-deploying-applications/05-sync-policies/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      # Apply changes from Git without being asked.
      prune: true
      # Revert changes made directly in the cluster. This is the setting that turns
      # "Argo CD noticed drift" into "Argo CD corrected drift".
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML_EOF

touch /tmp/kc-ready
