#!/bin/bash
# Scenario 2 background.sh — full stack: metrics-server + VPA + Goldilocks + sample app.
#
# The install body is written to /root/setup.sh (single source of truth) and run from
# there. foreground.sh re-runs /root/setup.sh if it detects an incomplete environment,
# so a transient failure here is recoverable rather than fatal. We deliberately do NOT
# use `set -e`: one failing command must never abort the rest of the setup.
set -uo pipefail


# Write the progress script the student actually sees. Killercoda pastes
# foreground.sh into the terminal line by line instead of executing it, so the
# real logic lives here and foreground.sh only hands off to it. This is written
# first, before any slow work, so the handoff is immediate.
cat > /root/progress.sh <<'PROGRESS'
set -uo pipefail

TIMEOUT=360   # hard ceiling before we stop waiting and print a diagnostic
GRACE=90      # how long to wait before attempting a self-heal re-run
ELAPSED=0

ready() {
  kubectl get deploy frontend api -n metrics-app >/dev/null 2>&1 || return 1
  [ "$(kubectl get pods -n metrics-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)" -ge 2 ] || return 1
  kubectl get pods -n goldilocks --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q . || return 1
  kubectl get pods -n vpa --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q . || return 1
  return 0
}

echo "Preparing the lab environment (this can take a few minutes)..."

# Wait for background.sh to write the installer before we consider self-healing.
while [ ! -f /root/setup.sh ] && [ "$ELAPSED" -lt 60 ]; do
  sleep 2; ELAPSED=$((ELAPSED + 2))
done

while ! ready; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Environment not fully ready after ${TIMEOUT}s."
    echo "Inspect with: kubectl get pods -A"
    break
  fi
  # Self-heal: past the grace period with the sample app still missing means the
  # background run likely aborted — re-run the idempotent installer in the foreground.
  if [ "$ELAPSED" -ge "$GRACE" ] && ! kubectl get deploy frontend -n metrics-app >/dev/null 2>&1; then
    echo "Setup looks incomplete — reconciling..."
    [ -f /root/setup.sh ] && bash /root/setup.sh
  fi
  echo "Waiting for environment... (${ELAPSED}s)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

if ready; then
  echo "Ready!"
fi
PROGRESS
chmod +x /root/progress.sh

# Write the idempotent installer. The outer heredoc is quoted ('SETUP') so nothing
# expands here — the inner heredocs are written verbatim and run when setup.sh executes.
cat > /root/setup.sh <<'SETUP'
#!/bin/bash
# Idempotent installer for the Goldilocks lab. Safe to run multiple times.
set -uo pipefail

# Wait for cluster
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 3; done

# Install Helm (only if missing)
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --no-sudo 2>/dev/null || true
fi

# Add repos
helm repo add fairwinds-stable https://charts.fairwinds.com/stable 2>/dev/null || true
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
for i in 1 2 3; do helm repo update 2>/dev/null && break || sleep 5; done

# Install metrics-server, VPA, and Goldilocks concurrently. They are independent at
# install time (Goldilocks is configured with vpa.enabled=false and
# metrics-server.enabled=false), so running them in parallel cuts setup wall-clock
# from the sum of their --wait timeouts to roughly the longest single one.
# `helm upgrade --install` reconciles cleanly even after a partial prior run.
( helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set 'args[0]=--kubelet-insecure-tls' \
    --wait --timeout 120s 2>/dev/null || true ) &

( kubectl create namespace vpa 2>/dev/null || true
  helm upgrade --install vpa fairwinds-stable/vpa \
    --namespace vpa --version 4.12.0 \
    --wait --timeout 180s 2>/dev/null || true ) &

( kubectl create namespace goldilocks 2>/dev/null || true
  cat > /tmp/goldilocks-values.yaml <<'EOF'
image:
  repository: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks
  tag: v4.15.1
vpa:
  enabled: false
metrics-server:
  enabled: false
EOF
  helm upgrade --install goldilocks fairwinds-stable/goldilocks \
    --namespace goldilocks --version 10.4.0 \
    -f /tmp/goldilocks-values.yaml \
    --wait --timeout 180s 2>/dev/null || true ) &

# Barrier: wait for all three installs before deploying the sample app.
wait

# Deploy sample app (metrics-app) — WITHOUT goldilocks label
kubectl create namespace metrics-app 2>/dev/null || true

# frontend: over-provisioned nginx
kubectl apply -f - <<'EOF' || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: metrics-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: metrics-app
spec:
  selector:
    app: frontend
  ports:
  - port: 80
EOF

# api: under-provisioned httpbin
kubectl apply -f - <<'EOF' || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: metrics-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        resources:
          requests:
            cpu: "10m"
            memory: "32Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: metrics-app
spec:
  selector:
    app: api
  ports:
  - port: 80
EOF

# load generator (generates traffic for VPA to observe)
kubectl apply -f - <<'EOF' || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
  namespace: metrics-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      containers:
      - name: load-generator
        image: busybox
        command:
        - sh
        - -c
        - "while true; do wget -q -O /dev/null http://frontend/ 2>/dev/null; sleep 1; done"
        resources:
          requests:
            cpu: "10m"
            memory: "8Mi"
          limits:
            cpu: "50m"
            memory: "32Mi"
EOF

# Wait for pods
kubectl wait --for=condition=Ready pods -l app=frontend -n metrics-app --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=Ready pods -l app=api -n metrics-app --timeout=120s 2>/dev/null || true

echo "[setup] Scenario 2 stack ready."
SETUP

chmod +x /root/setup.sh
bash /root/setup.sh
echo "[background] Scenario 2 ready."
