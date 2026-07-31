#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# Scenarios 1 to 6 built things and locked them down. This one is about knowing
# when any of it breaks, and about the two layers above a plain sync: a canary
# that pauses, and a platform that bootstraps itself from one file.
#
# Beyond Argo CD this installs Argo Rollouts and its kubectl plugin, because
# step 4 runs a real canary rather than describing one.
#
# No `set -e`: a failed optional step should degrade the environment, not abort setup.

mkdir -p /var/log/killercoda
LOG=/var/log/killercoda/background.log
ARGOCD_VERSION="v3.4.5"
ROLLOUTS_VERSION="v1.9.1"

# ── Write the progress script FIRST ───────────────────────────────────────────
# Killercoda pastes foreground.sh into the student's terminal line by line rather
# than executing it as a file, so anything inline there is echoed as if the
# student typed it. Keeping foreground.sh to two lines that just run this file
# means the student sees output only. This must be written before the slow work
# below, or foreground.sh sits waiting on a file that does not exist yet.
cat > /root/progress.sh <<'PROGRESS'
steps=(
  "Waiting for the Kubernetes cluster"
  "Installing the argocd CLI"
  "Installing Argo CD 3.4.5"
  "Waiting for Argo CD to be ready"
  "Registering Argo Rollouts 1.9.1"
)
signals=(
  "/tmp/kc-step1"
  "/tmp/kc-step2"
  "/tmp/kc-step3"
  "/tmp/kc-step4"
  "/tmp/kc-step5"
)

echo ""
echo "  Setting up Argo CD and Argo Rollouts. Usually four to six minutes,"
echo "  but it depends on how fast this VM pulls images, so give it longer."
echo "  This one is about seeing what broke, and what runs on top of a sync."
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
# the 262144 byte annotation that client-side apply writes.
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

# Pre-pull every image the steps use. The canary in step 4 runs two tags at once,
# and without this the student watches an image pull instead of a canary.
crictl pull docker.io/library/nginx:1.29-alpine >>"$LOG" 2>&1 || true
crictl pull docker.io/library/nginx:1.28-alpine >>"$LOG" 2>&1 || true

# ── Phase 5: Argo Rollouts, for step 4's canary ───────────────────────────────
# A separate install with its own CRDs, which is exactly the ordering point
# Module 5 made: the Rollout CRD must exist before any Rollout object.
kubectl create namespace argo-rollouts >>"$LOG" 2>&1 || true
kubectl apply -n argo-rollouts --server-side --force-conflicts \
  -f "https://github.com/argoproj/argo-rollouts/releases/download/${ROLLOUTS_VERSION}/install.yaml" \
  >>"$LOG" 2>&1 || true

# Deliberately NOT waiting for the argo-rollouts Deployment to become Available.
# Measured on a real Killercoda VM, that wait pushed total setup from about five
# minutes to about thirteen, because it serialises the Rollouts image pull after
# Argo CD's. Steps 1 to 3 do not touch Rollouts at all, so the controller finishes
# coming up while the student works through them, and step 4 waits for it itself.
# What matters here is that the CRDs are registered, which the apply above does.

# The kubectl plugin, so `kubectl argo rollouts promote` works as written.
curl -sSL -o /usr/local/bin/kubectl-argo-rollouts \
  "https://github.com/argoproj/argo-rollouts/releases/download/${ROLLOUTS_VERSION}/kubectl-argo-rollouts-linux-amd64" \
  >>"$LOG" 2>&1 || true
chmod +x /usr/local/bin/kubectl-argo-rollouts 2>>"$LOG" || true
touch /tmp/kc-step5

# ── Manifests the steps apply ─────────────────────────────────────────────────
# Written here rather than via index.json assets, because an assets block was
# observed to deliver nothing at all and leave every step failing on a missing file.

mkdir -p /root/manifests/01-ownership
for N in owner-a owner-b; do
cat > "/root/manifests/01-ownership/${N}.yaml" <<YAML
# Two Applications, same repository, same path, same destination namespace.
# Nothing stops you creating this, and that is the point.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${N}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-06-applicationsets/03-git-generator/envs/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: contested
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML
done

mkdir -p /root/manifests/02-logs
cat > /root/manifests/02-logs/broken-repo.yaml <<'YAML'
# A repository that does not exist. The Application is perfectly valid YAML and
# kubectl accepts it without complaint.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: broken-repo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/this-repo-does-not-exist.git
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: broken
YAML

mkdir -p /root/manifests/04-canary
cat > /root/manifests/04-canary/canary-application.yaml <<'YAML'
# The Application does not mention Rollouts anywhere. It deploys a Rollout object
# exactly as it would deploy a Deployment. Argo CD owns the object; Argo Rollouts
# owns the progression.
#
# No automated sync: promotion here is deliberate, and selfHeal would fight an
# Argo Rollouts rollback.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: canary-web
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-11-progressive-delivery/03-wiring-argocd-with-rollouts/v1
  destination:
    server: https://kubernetes.default.svc
    namespace: canary-demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML

mkdir -p /root/manifests/05-bootstrap
cat > /root/manifests/05-bootstrap/root-application.yaml <<'YAML'
# The one file applied by hand. Everything else is discovered through it.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-12-capstone/01-repo-structure/apps
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

kubectl create namespace contested >>"$LOG" 2>&1 || true

touch /tmp/kc-ready
