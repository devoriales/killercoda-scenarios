# Step 1: Install the Vertical Pod Autoscaler

Goldilocks does not generate recommendations itself — it reads them from VPA. VPA must be installed first.

## Create the VPA namespace

```
kubectl create namespace vpa
``` {{copy}}

## Install VPA via Helm

```
helm install vpa fairwinds-stable/vpa \
  --namespace vpa \
  --version 4.12.0 \
  --wait \
  --timeout 180s
``` {{copy}}

This installs three components:
- **vpa-recommender** — reads metrics, computes CPU/memory recommendations
- **vpa-updater** — applies recommendations (we'll use Off mode, so it stays idle)
- **vpa-admission-controller** — intercepts pod creation to set initial resources

## Verify VPA is running

```
kubectl get pods -n vpa
``` {{copy}}

All three pods should show `1/1 Running`. This may take up to 60 seconds.

Also verify the VPA Custom Resource Definitions exist:

```
kubectl get crd | grep autoscaling.k8s.io
``` {{copy}}

You should see `verticalpodautoscalers.autoscaling.k8s.io` and `verticalpodautoscalercheckpoints.autoscaling.k8s.io`.
