#!/bin/bash
# Scenario 2 background.sh — full stack: metrics-server + VPA + Goldilocks + sample app
set -euo pipefail

# Wait for cluster
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 3; done

# Install Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --no-sudo 2>/dev/null

# Add repos
helm repo add fairwinds-stable https://charts.fairwinds.com/stable 2>/dev/null || true
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update 2>/dev/null

# Install metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args[0]=--kubelet-insecure-tls' \
  --wait --timeout 120s 2>/dev/null || true

# Install VPA
kubectl create namespace vpa 2>/dev/null || true
helm install vpa fairwinds-stable/vpa \
  --namespace vpa --version 4.12.0 \
  --wait --timeout 180s 2>/dev/null || true

# Install Goldilocks
kubectl create namespace goldilocks 2>/dev/null || true
cat > /tmp/goldilocks-values.yaml <<'EOF'
image:
  repository: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks
  tag: v4.15.1
vpa:
  enabled: false
metrics-server:
  enabled: false
EOF

helm install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks --version 10.4.0 \
  -f /tmp/goldilocks-values.yaml \
  --wait --timeout 180s 2>/dev/null || true

# Deploy sample app (metrics-app) — WITHOUT goldilocks label
kubectl create namespace metrics-app 2>/dev/null || true

# frontend: over-provisioned nginx
kubectl apply -f - <<'EOF'
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
kubectl apply -f - <<'EOF'
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
kubectl apply -f - <<'EOF'
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

echo "[background] Scenario 2 ready."
