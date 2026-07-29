#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# Scenario 1 taught installing Argo CD, so this scenario starts with it already
# installed and gets straight to Applications. That means this script does the
# whole install, waits for it to be usable, and pre-pulls the workload image so
# the student's first sync completes in seconds rather than minutes.
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
echo "  Installing it was scenario 1. This one is about what you build on top."
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

# Pre-pull the workload image so the student's first sync goes Healthy quickly.
crictl pull docker.io/library/nginx:1.29-alpine >>"$LOG" 2>&1 || true

# Write the manifests the steps reference. Killercoda's `assets` block did not
# deliver them (the target directory simply did not exist), and background.sh is
# the mechanism this repo already relies on for files the student must apply.
mkdir -p /root/manifests/01-application
cat > /root/manifests/01-application/demo-application.yaml <<'YAML_EOF'
# The Application resource: one object that says WHERE the desired state lives and
# WHERE it should end up. Everything else Argo CD does follows from these two answers.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo
  # The Application itself lives in the argocd namespace, NOT in the namespace it
  # deploys to. This trips people up constantly: `kubectl get application demo` in the
  # demo namespace returns nothing.
  namespace: argocd
spec:
  # Which AppProject governs this app. `default` allows everything, which is why the
  # next lesson replaces it.
  project: default

  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    # Path within the repo. Argo CD renders whatever it finds here: plain YAML in this
    # case, but the same field points at a Kustomize or Helm directory later.
    path: module-03-core-concepts/01-application-crd/manifests

  destination:
    # https://kubernetes.default.svc means "the cluster Argo CD itself runs in".
    server: https://kubernetes.default.svc
    namespace: demo

  syncPolicy:
    syncOptions:
      # Argo CD will not create the target namespace unless you ask it to. Without this
      # the first sync fails with "namespace not found", which looks like a permissions
      # problem and is not.
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/02-appproject
cat > /root/manifests/02-appproject/restricted-project.yaml <<'YAML_EOF'
# An AppProject that constrains what its Applications may do.
#
# clusterResourceWhitelist: [] is the important line. An empty list means
# "nothing cluster-scoped at all", not "no restriction", so an Application in
# this project cannot create a ClusterRole, a CRD, or even a Namespace.
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: course
  namespace: argocd
spec:
  description: Only this course's repo, only the demo namespace, no cluster-scoped resources.
  sourceRepos:
    - https://github.com/devoriales/argocd-beginner.git
  destinations:
    - server: https://kubernetes.default.svc
      namespace: demo
  clusterResourceWhitelist: []
  namespaceResourceWhitelist:
    - group: apps
      kind: Deployment
    - group: ''
      kind: Service
YAML_EOF

mkdir -p /root/manifests/02-appproject
cat > /root/manifests/02-appproject/forbidden-app.yaml <<'YAML_EOF'
# An Application that the `course` project will refuse.
#
# The repo below is a real, working Argo CD example repo. Nothing is wrong with
# it. It is simply not in the project's sourceRepos list, which is the whole
# point: the rejection is about the boundary, not about the manifests.
#
# kubectl apply will succeed. The refusal arrives later, as a condition on the
# Application, which is why a pipeline that only checks the apply exit code
# reports this as a successful deployment.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: forbidden
  namespace: argocd
spec:
  project: course
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
YAML_EOF

mkdir -p /root/manifests/03-health
cat > /root/manifests/03-health/broken-application.yaml <<'YAML_EOF'
# Deploys a manifest that is valid but cannot run, to show that Sync status and Health
# status are independent. Sync answers "does the cluster match Git?". Health answers
# "is the thing actually working?".
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: broken
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-03-core-concepts/04-sync-vs-health/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/04-app-of-apps
cat > /root/manifests/04-app-of-apps/root-application.yaml <<'YAML_EOF'
# The app-of-apps pattern: an Application whose source directory contains other
# Application manifests. Argo CD manages Argo CD.
#
# Bootstrapping a cluster becomes applying this one file. Everything else is
# discovered from Git, which means adding a workload later is a pull request rather
# than a kubectl command.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    # This directory holds Application manifests, not workloads.
    path: module-03-core-concepts/05-app-of-apps/apps
  destination:
    server: https://kubernetes.default.svc
    # The children are Argo CD objects, so they land in the argocd namespace.
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML_EOF

touch /tmp/kc-ready
