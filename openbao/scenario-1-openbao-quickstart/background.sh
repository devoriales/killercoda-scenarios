#!/bin/bash
# Runs silently before the student arrives. Nothing here is visible to them.
#
# The goal is to make the student's own `helm install` fast, without doing any of
# the work the scenario teaches. So this installs Helm, adds the chart repo and
# pre-pulls the OpenBao image (about 75 MB), but deliberately does NOT install
# OpenBao. That is step 1.
#
# No `set -e`: a failed optional step should degrade the environment, not abort setup.

mkdir -p /var/log/killercoda /root/manifests
LOG=/var/log/killercoda/background.log
OPENBAO_IMAGE="quay.io/openbao/openbao:2.6.1"
CHART_VERSION="0.28.6"

# ── Write the progress script FIRST ───────────────────────────────────────────
# Killercoda pastes foreground.sh into the student's terminal line by line rather
# than executing it as a file, so anything inline there is echoed as if the student
# typed it. Keeping foreground.sh to four lines that just `bash /root/progress.sh`
# means the student sees output only. Written before the slow work below, or
# foreground.sh sits waiting on a file that does not exist yet.
cat > /root/progress.sh <<'PROGRESS'
steps=(
  "Waiting for the Kubernetes cluster"
  "Installing Helm and the OpenBao chart repo"
  "Pre-pulling the OpenBao image"
)
signals=(
  "/tmp/kc-step1"
  "/tmp/kc-step2"
  "/tmp/kc-step3"
)

echo ""
echo "  Preparing your cluster. This takes a minute or two."
echo "  The image is pulled up front so your own install is quick."
echo ""

for i in "${!signals[@]}"; do
  printf "  ... %s\n" "${steps[$i]}"
  while [ ! -f "${signals[$i]}" ]; do sleep 2; done
  printf "  OK  %s\n" "${steps[$i]}"
done

while [ ! -f /tmp/kc-ready ]; do sleep 1; done

echo ""
echo "  Ready. OpenBao is NOT installed yet, that is your job."
echo "  Read the introduction on the left, then click START."
echo ""
PROGRESS
chmod +x /root/progress.sh

# ── Phase 1: cluster ready ────────────────────────────────────────────────────
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 3; done
# Single-node clusters keep the control-plane taint, which would leave the OpenBao
# pod Pending forever with no obvious cause.
kubectl taint nodes --all node-role.kubernetes.io/control-plane- >>"$LOG" 2>&1 || true
touch /tmp/kc-step1

# ── Phase 2: Helm, chart repo, jq ─────────────────────────────────────────────
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | bash >>"$LOG" 2>&1 || true
fi
helm repo add openbao https://openbao.github.io/openbao-helm >>"$LOG" 2>&1 || true
helm repo update >>"$LOG" 2>&1 || true
command -v jq >/dev/null 2>&1 || apt-get install -y jq >>"$LOG" 2>&1 || true

# The values file the student applies in step 1. Written here rather than declared
# as an `assets` block: an assets declaration has been observed to deliver nothing
# at all, leaving every step failing at its first command with no error in the UI.
cat > /root/manifests/values-quickstart.yaml <<'YAML_EOF'
# Standalone OpenBao for the quickstart. Deliberately minimal.
#
# No TLS here: this is a throwaway browser VM and the subject of this scenario is
# the seal lifecycle, not certificate bootstrapping. The k3d lesson on
# devoriales.com deploys with TLS on the listener from the first boot, which is a
# different and equally deliberate choice.
server:
  image:
    repository: openbao/openbao
    tag: "2.6.1"
  standalone:
    enabled: true
    config: |
      ui = true
      listener "tcp" {
        address     = "[::]:8200"
        tls_disable = 1
      }
      storage "file" {
        path = "/openbao/data"
      }
  dataStorage:
    enabled: true
    size: 1Gi
  # The chart's default readiness probe runs `bao status`, whose exit code is the
  # seal status. That is exactly right here: the pod stays NotReady while sealed,
  # which is the behaviour step 2 asks the student to observe.
  readinessProbe:
    enabled: true
  # Liveness stays off. No HTTP health check can tell "wedged" from
  # "healthy but sealed", so enabling it restarts the pod during init and unseal.
  livenessProbe:
    enabled: false
injector:
  enabled: false
YAML_EOF

# A `bao` wrapper on PATH, so the student can type `bao status` instead of a
# kubectl exec incantation on every line.
#
# This is a wrapper script rather than an alias or an export in .bashrc on purpose:
# the student's shell is spawned before this script finishes, so nothing appended
# to .bashrc is ever sourced by the terminal they actually type into. A file on
# PATH works regardless of when the shell started.
cat > /usr/local/bin/bao <<'BAO_EOF'
#!/bin/bash
# Runs the real bao binary inside the OpenBao pod, forwarding the token if set.
exec kubectl exec -n openbao openbao-0 -- \
  env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="${BAO_TOKEN:-}" bao "$@"
BAO_EOF
chmod +x /usr/local/bin/bao
touch /tmp/kc-step2

# ── Phase 3: pre-pull the image ───────────────────────────────────────────────
# Pulled through the cluster's own runtime so it lands in the node's image store
# and the student's install does not sit in ContainerCreating.
if command -v crictl >/dev/null 2>&1; then
  crictl pull "$OPENBAO_IMAGE" >>"$LOG" 2>&1 || true
else
  ctr -n k8s.io images pull "$OPENBAO_IMAGE" >>"$LOG" 2>&1 || true
fi
# Pull the chart too, so `helm install` does not need the network at student time.
helm pull openbao/openbao --version "$CHART_VERSION" -d /root/manifests >>"$LOG" 2>&1 || true
touch /tmp/kc-step3

touch /tmp/kc-ready
