#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# Scenarios 1 to 5 covered installing Argo CD and deploying with it at scale. This
# one is about the boundaries: what an Application may do, who may act on it, where
# it may be declared, and proving a commit was authorised.
#
# Beyond installing Argo CD this also installs Sealed Secrets and the kubeseal
# binary, because step 4 does a real encrypt-and-decrypt round trip rather than
# describing one.
#
# It deliberately leaves argocd-rbac-cm EMPTY, which is how a stock install ships.
# Step 2 has the student see that before changing it.
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
# student typed it. Keeping foreground.sh to two lines that just run this file
# means the student sees output only. This must be written before the slow work
# below, or foreground.sh sits waiting on a file that does not exist yet.
cat > /root/progress.sh <<'PROGRESS'
steps=(
  "Waiting for the Kubernetes cluster"
  "Installing the argocd CLI"
  "Installing Argo CD 3.4.5"
  "Waiting for Argo CD to be ready"
  "Installing Sealed Secrets and kubeseal"
)
signals=(
  "/tmp/kc-step1"
  "/tmp/kc-step2"
  "/tmp/kc-step3"
  "/tmp/kc-step4"
  "/tmp/kc-step5"
)

echo ""
echo "  Setting up Argo CD for you. This takes three to four minutes."
echo "  Installing it was scenario 1. This one is about BOUNDARIES and trust."
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

# Pre-pull the workload image. Every Application in this scenario deploys the same
# nginx Deployment, so without this the student waits on a pull while trying to read
# whether a project accepted or refused their Application.
crictl pull docker.io/library/nginx:1.29-alpine >>"$LOG" 2>&1 || true

# ── Sealed Secrets, for step 4's encrypt and decrypt round trip ────────────────
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.3/controller.yaml >>"$LOG" 2>&1 || true
for _ in $(seq 1 30); do
  [ "$(kubectl get deploy sealed-secrets-controller -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "1" ] && break
  sleep 5
done

# kubeseal as a real binary on PATH, not the container image. Running it as a container
# means mounting a kubeconfig into it, which turns a one-line student command into an
# unreadable one and teaches nothing about sealing.
curl -sSL -o /tmp/kubeseal.tar.gz \
  "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.3/kubeseal-0.27.3-linux-amd64.tar.gz" \
  >>"$LOG" 2>&1 || true
tar -xzf /tmp/kubeseal.tar.gz -C /tmp kubeseal >>"$LOG" 2>&1 || true
install -m 0755 /tmp/kubeseal /usr/local/bin/kubeseal >>"$LOG" 2>&1 || true
touch /tmp/kc-step5

# The trusted PUBLIC key for step 5's signature verification.
#
# Baked in rather than generated at runtime, deliberately. Generating a key needs
# gpg, the backend image may not ship it, and a `command -v gpg` guard would
# silently skip this and leave the step broken with no error.
#
# Only the PUBLIC half is needed and only the public half is here: the lab proves
# that an UNSIGNED repository is refused, so it never signs anything and never
# needs a private key. Embedding a private key in a public lab would be exactly
# the practice this module warns against.
mkdir -p /root/manifests/04-security
cat > /root/manifests/04-security/trusted-key.asc <<'GPGKEY_EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQGNBGpqIfEBDADUHG4r0h1M7xz+cfJZAiOzMWs38tUAcvTX3RQ5vEJovHWOsBL/
NxFrE9KItmKc8KqgFSIuJoqnukePpqoxiE+Hq/enBGMglxe3pEarqfv0bS36ifws
XQ6eW0Vu6XREjeA+p2nwx3rXmBCgHdkkiqs5wdSV1EU+VoC0IhD5TwgUATlOfL++
7kWEhrtS1pgH6zUaEeSpSzcppFEKBTqn5RYRgRfhA1tzKh5eBzPIsIEgeP/9mYX/
r+E+pPX8Knd52oKDRbLxCOjJkCP5mdscOR/J7mL5DalIlwisvZmI3ryGjjy+Dpc6
PT9jyv1s3WzWeFfIEWJi2qPT/WlX2kn0c4ZBbj7xtbPOv2oTHpJHjWsQ3NtsF9Mh
FUs+AyFhsGyG9rspi1d5fJwN7MshTawWrHQR9P81VZrDTbdyboLyYnMo1y7k/p2I
sXIG13kJRSCjTp8yfpQqpgW4lkKlS8jVLEp3DxFUNrDjiU03eGbJtZJer1ojLpX9
+3B+o5ZI4EN7TikAEQEAAbQpQXJnbyBDRCBDb3Vyc2UgRGVtbyA8ZGVtb0BkZXZv
cmlhbGVzLmNvbT6JAc8EEwEKADkWIQR4hOY2YSuS+kimOzFSmxE4xFhxtwUCamoh
8QMbLwQFCwkIBwIGFQoJCAsCBBYCAwECHgECF4AACgkQUpsROMRYcbf76Qv9Fw7q
w9lSXp/8qy9vaVUcKQVmSBiVozhiJodifVjl5NqY5r7yhCVvZxO2K47ROfx9TIC8
zOBgkuLc3kpdAoAu87Q/WXjkFzUxnjcGZGg91UABSex8EmQor4PE7Gmsj2xxGcVa
Fr67mBhZvxkyivIBaKKaiaxh9fk4hKTCDAg/gsR9vi9iAvT8ecI65nrSchaYX63a
dZL+y9X5KMb5MDVp8Bo2WPFAXL9SGevmO12arm35WaKm550JtauusebPdXl6LHGD
AYVTBYjQ2hq/+XsfHNQfpLDMpGYxNPxvyWwjlG7Zdec1mImrNmDSkkfUnIErcau8
+IccxyNF08yuRzJiKyK0B7Eh/s1/pOYtPw2nf0qK2EtgAOaqMIzDGL1wv+IAckpo
AC16OcWRkQH09nyvUnsb3ERSgH9UToqV4ua/QLsy/HP7o9Z2T3FsdNxvHHAiUeJS
hKVhaYszDKK2kuvOgSYYxDn1ZAy36GyxwnbhwQFnkEPrByR0oStbHP/WRsW3
=r9Yj
-----END PGP PUBLIC KEY BLOCK-----
GPGKEY_EOF
echo "529B1138C45871B7" > /root/demo-keyid.txt

# ── Manifests the steps apply ─────────────────────────────────────────────────
# Written here rather than via index.json assets, because an assets block was
# observed to deliver nothing at all and leave every step failing on a missing file.

mkdir -p /root/manifests/01-project
cat > /root/manifests/01-project/tenant-project.yaml <<'YAML_EOF'
# A least-privilege AppProject. Every entry is something you decided to allow,
# which is the opposite of the default project's sourceRepos: ['*'].
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: tenant-a
  namespace: argocd
spec:
  description: Tenant A. Own repo, own namespaces, nothing cluster-scoped.
  sourceRepos:
    - https://github.com/devoriales/argocd-beginner.git
  destinations:
    - server: https://kubernetes.default.svc
      namespace: 'tenant-a-*'
  # The line that stops privilege escalation. An empty list means NOTHING
  # cluster-scoped: no ClusterRole, no ClusterRoleBinding, no CRD, no Namespace.
  clusterResourceWhitelist: []
  # ResourceQuota is namespaced and therefore allowed by default, so a tenant
  # subject to a quota could otherwise commit a bigger one.
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: rbac.authorization.k8s.io
      kind: RoleBinding
YAML_EOF

cat > /root/manifests/01-project/rejected-repo.yaml <<'YAML_EOF'
# Points at a real, working repository that is simply not on the project's list.
# kubectl apply will SUCCEED. The refusal arrives later as a condition, which is
# why a pipeline checking only the apply exit code reports this as a success.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rejected-repo
  namespace: argocd
spec:
  project: tenant-a
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: tenant-a-web
YAML_EOF

cat > /root/manifests/01-project/rejected-namespace.yaml <<'YAML_EOF'
# The right repo, the wrong destination. kube-system is not in the project's
# namespace glob, so this is refused too, for a different reason.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rejected-namespace
  namespace: argocd
spec:
  project: tenant-a
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-06-applicationsets/03-git-generator/envs/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
YAML_EOF

cat > /root/manifests/01-project/allowed.yaml <<'YAML_EOF'
# Inside every boundary: approved repo, namespace matching the glob.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tenant-a-web
  namespace: argocd
spec:
  project: tenant-a
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-06-applicationsets/03-git-generator/envs/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: tenant-a-web
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/03-namespaces
cat > /root/manifests/03-namespaces/tenant-app.yaml <<'YAML_EOF'
# An Application declared in the TENANT'S namespace rather than in argocd.
# On a stock install this is accepted by Kubernetes and completely ignored by
# Argo CD: no status, no conditions, no events. Silence.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tenant-owned
  namespace: tenant-a
spec:
  project: tenant-a
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-06-applicationsets/03-git-generator/envs/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: tenant-a-owned
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

mkdir -p /root/manifests/04-security
cat > /root/manifests/04-security/plain-secret.yaml <<'YAML_EOF'
# The thing you must never commit. base64 is an ENCODING, not encryption:
# `base64 -d` needs no key and no privilege.
apiVersion: v1
kind: Secret
metadata:
  name: db-password
  namespace: sealed-demo
type: Opaque
stringData:
  password: hunter2-the-real-password
YAML_EOF

cat > /root/manifests/04-security/signed-only-project.yaml <<'YAML_EOF'
# A project that will only deploy commits signed by a trusted key.
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: signed-only
  namespace: argocd
spec:
  sourceRepos: ['*']
  destinations:
    - server: https://kubernetes.default.svc
      namespace: '*'
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  signatureKeys:
    - keyID: 529B1138C45871B7
YAML_EOF

cat > /root/manifests/04-security/unsigned-app.yaml <<'YAML_EOF'
# The course repository's commits are not GPG signed, so this Application is the
# demonstration: a perfectly valid app that the project refuses to deploy.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: unsigned-app
  namespace: argocd
spec:
  project: signed-only
  source:
    repoURL: https://github.com/devoriales/argocd-beginner.git
    targetRevision: main
    path: module-06-applicationsets/03-git-generator/envs/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: signed-demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML_EOF

kubectl create namespace tenant-a >>"$LOG" 2>&1 || true
kubectl create namespace sealed-demo >>"$LOG" 2>&1 || true

touch /tmp/kc-ready
