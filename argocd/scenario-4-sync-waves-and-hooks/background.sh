#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# Scenarios 1 to 3 covered installing Argo CD and deploying with it, so this one
# starts with all of that done and goes straight to ordering and lifecycle. This
# script does the whole install, waits for it to be usable, and pre-pulls both
# images the steps need so the wave demo is quick rather than image-bound.
#
# The CLI is put into core mode. Core mode talks to the Kubernetes API directly
# instead of to argocd-server, so there is no port-forward to keep alive and no
# password to paste. Every `argocd app ...` command behaves the same either way.
#
# No `set -e`: a failed optional step should degrade the environment, not abort setup.

mkdir -p /var/log/killercoda
LOG=/var/log/killercoda/background.log
ARGOCD_VERSION="v3.4.5"

# ── Write the progress script FIRST ───────────────────────────────────────────
# Killercoda pastes foreground.sh into the student's terminal line by line rather
# than executing it as a file, so anything inline there is echoed as if the
# student typed it. Keeping foreground.sh to four lines that just run this file
# means the student sees output only. This must be written before the slow work
# below, or foreground.sh sits waiting on a file that does not exist yet.
cat > /root/progress.sh <<'PROGRESS'
steps=(
  "Waiting for the Kubernetes cluster"
  "Installing the argocd CLI"
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
echo "  Installing it was scenario 1. This one is about ORDER and lifecycle."
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

# ── Phase 2: argocd CLI ───────────────────────────────────────────────────────
curl -sSL -o /usr/local/bin/argocd \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" \
  >>"$LOG" 2>&1 || true
chmod +x /usr/local/bin/argocd 2>>"$LOG" || true

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

# Pre-pull BOTH images the steps use. busybox runs every Job (migrations, hooks,
# smoke tests) and nginx is every workload. Without this the wave demo measures
# image pull time rather than the wave gate, which is the whole point of step 1.
crictl pull docker.io/library/nginx:1.29-alpine >>"$LOG" 2>&1 || true
crictl pull docker.io/library/busybox:1.37 >>"$LOG" 2>&1 || true


# Write the manifests the steps reference. These are the Application and AppProject
# objects only: the workloads they deploy live in the public course repo, so the
# student sees Argo CD pulling from Git exactly as they would in production.
#
# Written here rather than via index.json assets, because an assets block was
# observed to deliver nothing at all and leave every step failing on a missing file.
mkdir -p /root/manifests/01-waves
cat > /root/manifests/01-waves/waves-application.yaml <<'YAML_EOF'
# One directory, three resources, three waves.
#
# Nothing in this Application mentions ordering. The waves live as annotations
# on the resources themselves, which means the ordering travels with the
# manifests rather than with whoever happens to be deploying them.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: waves
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-05-sync-strategies/01-sync-waves/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF
mkdir -p /root/manifests/02-hooks
cat > /root/manifests/02-hooks/hooks-application.yaml <<'YAML_EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hooks
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-05-sync-strategies/02-sync-hooks/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF
mkdir -p /root/manifests/03-policies
cat > /root/manifests/03-policies/policies-application.yaml <<'YAML_EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: policies
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-05-sync-strategies/04-hook-deletion-policies/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF
mkdir -p /root/manifests/04-windows
cat > /root/manifests/04-windows/windowed-project.yaml <<'YAML_EOF'
# An AppProject carrying a sync window.
#
# Windows are scheduling policy, not permission policy. They answer "may a sync
# happen right now", which is a different question from "is this repo allowed",
# and they are evaluated per Application through the project it belongs to.
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: windowed
  namespace: argocd
spec:
  sourceRepos: ['*']
  destinations:
    - server: '*'
      namespace: '*'
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  syncWindows:
    # A deny window that is always active, so the demo is deterministic rather
    # than depending on what time you happen to run it. A real one looks like
    # schedule: '0 9 * * 1-5' with duration 8h, meaning office hours.
    - kind: deny
      schedule: '* * * * *'
      duration: 24h
      applications: ['*']
      # Flip this to true and a human may still sync by hand while automation
      # stays blocked. That is the useful setting for a change freeze.
      manualSync: false
YAML_EOF
mkdir -p /root/manifests/04-windows
cat > /root/manifests/04-windows/windowed-application.yaml <<'YAML_EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: windowed-app
  namespace: argocd
spec:
  # The window comes from the project, not from the Application.
  project: windowed
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-03-core-concepts/05-app-of-apps/workloads/web
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
YAML_EOF

touch /tmp/kc-ready
