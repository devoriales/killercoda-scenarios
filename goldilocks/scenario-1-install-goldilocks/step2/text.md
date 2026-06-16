# Step 2: Install Goldilocks

## Create the Goldilocks namespace

```
kubectl create namespace goldilocks
```

## Create the Helm values file

Goldilocks v4.15.1 moved to a new container registry. Create a values file to pin the correct image:

```
cat > /root/goldilocks-values.yaml <<'EOF'
image:
  repository: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks
  tag: v4.15.1
vpa:
  enabled: false
metrics-server:
  enabled: false
EOF
``` {{copy}}

The `vpa.enabled: false` and `metrics-server.enabled: false` flags prevent Goldilocks from installing its own bundled copies — we already have those.

## Install Goldilocks

```
helm install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --version 10.4.0 \
  -f /root/goldilocks-values.yaml \
  --wait \
  --timeout 180s
``` {{copy}}

## What gets installed

Goldilocks deploys two components:

| Component | Role |
|-----------|------|
| `goldilocks-controller` | Watches labeled namespaces, creates VPA objects for each Deployment |
| `goldilocks-dashboard` | Web UI that reads VPA recommendations and displays them |
