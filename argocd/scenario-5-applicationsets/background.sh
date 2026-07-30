#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# Scenarios 1 to 4 covered installing Argo CD, deploying with it, and controlling
# order. This one is about generating Applications instead of writing them. The
# script installs Argo CD, waits for it to be usable, and pre-pulls the workload
# image, because a List generator producing three Applications at once would
# otherwise spend its time pulling the same image three times.
#
# It deliberately does NOT enable progressive syncs. Step 4 has the student
# discover that it is off by default, which is the entire point of that step.
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
echo "  Installing it was scenario 1. This one is about GENERATING Applications."
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



# Write the ApplicationSet manifests the steps reference. These are Argo CD objects
# only: the workloads they generate Applications for live in the public course repo,
# under module-06-applicationsets/03-git-generator/envs/{dev,staging,prod}.
#
# Written here rather than via index.json assets, because an assets block was
# observed to deliver nothing at all and leave every step failing on a missing file.

mkdir -p /root/manifests/01-list
cat > /root/manifests/01-list/appset-list.yaml <<'YAML_EOF'
# The simplest generator: a literal list you maintain.
#
# One ApplicationSet, three Applications. A generator produces a set of parameter
# maps, and the template is instantiated once per map with {{...}} substituted.
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: list-demo
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
          - env: staging
          - env: prod
  template:
    metadata:
      # The name MUST contain a parameter. Without one, three elements generate
      # three Applications with the same name, which is one Application being
      # rewritten three times.
      name: 'list-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/devoriales/argocd-beginner.git
        targetRevision: main
        path: 'module-06-applicationsets/03-git-generator/envs/{{env}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: demo
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/02-discover
cat > /root/manifests/02-discover/appset-git.yaml <<'YAML_EOF'
# The Git generator derives the list from the repository, so adding an environment
# becomes adding a folder rather than editing this file.
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: git-demo
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/devoriales/argocd-beginner.git
        revision: main
        directories:
          - path: module-06-applicationsets/03-git-generator/envs/*
  template:
    metadata:
      # {{path.basename}} is the folder name. {{path}} contains slashes and is
      # not a legal Application name.
      name: 'git-{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/devoriales/argocd-beginner.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: git-demo
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
YAML_EOF

cat > /root/manifests/02-discover/appset-cluster.yaml <<'YAML_EOF'
# An empty clusters: {} means every cluster Argo CD knows about. On a single
# cluster install that is not zero: the cluster Argo CD runs in is always a
# target, called in-cluster, and needs no credential secret.
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-demo
  namespace: argocd
spec:
  generators:
    - clusters: {}
  template:
    metadata:
      name: 'cl-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/devoriales/argocd-beginner.git
        targetRevision: main
        path: module-06-applicationsets/03-git-generator/envs/dev
      destination:
        server: '{{server}}'
        namespace: cluster-demo
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/03-matrix
cat > /root/manifests/03-matrix/appset-matrix.yaml <<'YAML_EOF'
# matrix produces the CROSS PRODUCT of two generators. Two environments times two
# regions is four Applications, and the parameters from both are available in the
# template at once.
#
# Work the multiplication out before applying. Three environments across four
# clusters is twelve Applications from one object, and adding a cluster adds three
# more without you editing anything.
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: matrix-demo
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - env: dev
                - env: staging
          - list:
              elements:
                - region: eu
                - region: us
  template:
    metadata:
      name: 'mx-{{env}}-{{region}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/devoriales/argocd-beginner.git
        targetRevision: main
        path: 'module-06-applicationsets/03-git-generator/envs/{{env}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: matrix-demo
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/04-rolling
cat > /root/manifests/04-rolling/appset-rolling.yaml <<'YAML_EOF'
# RollingSync updates the generated Applications in ordered steps, waiting for each
# step to become Healthy before starting the next.
#
# Two things are easy to get wrong here:
#   * the feature is DISABLED by default, and a RollingSync strategy is then
#     silently ignored rather than rejected
#   * steps match on LABELS of the generated Applications, not on generator
#     parameters, which is why the template sets envLabel explicitly
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: rolling-demo
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
          - env: staging
          - env: prod
  strategy:
    type: RollingSync
    rollingSync:
      steps:
        - matchExpressions:
            - key: envLabel
              operator: In
              values: [dev]
        - matchExpressions:
            - key: envLabel
              operator: In
              values: [staging]
        - matchExpressions:
            - key: envLabel
              operator: In
              values: [prod]
  template:
    metadata:
      name: 'roll-{{env}}'
      labels:
        envLabel: '{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/devoriales/argocd-beginner.git
        targetRevision: main
        path: 'module-06-applicationsets/03-git-generator/envs/{{env}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: rolling-demo
      syncPolicy:
        automated: {}
        syncOptions:
          - CreateNamespace=true
YAML_EOF

touch /tmp/kc-ready
