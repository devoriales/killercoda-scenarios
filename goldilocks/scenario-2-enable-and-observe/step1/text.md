# Step 1: Explore the Sample App

## Wait for the environment to be ready

The background setup (metrics-server, VPA, Goldilocks, sample app) takes a few minutes.
Run this first and wait until it prints `Ready!`:

```
until kubectl get deploy frontend api -n metrics-app &>/dev/null \
  && kubectl get pods -n metrics-app --field-selector=status.phase=Running \
     --no-headers 2>/dev/null | grep -q . \
  && kubectl get pods -n goldilocks --field-selector=status.phase=Running \
     --no-headers 2>/dev/null | grep -q .; do
  echo "Waiting for environment..."; sleep 5
done
echo "Ready!"
```{{copy}}

Before enabling Goldilocks, inspect the existing deployments to understand what's misconfigured.

## List the deployments

```
kubectl get deployments -n metrics-app
```{{copy}}

## Check resource settings for each deployment

```
kubectl get deployment frontend -n metrics-app \
  -o jsonpath='{.spec.template.spec.containers[0].resources}' | python3 -m json.tool
```{{copy}}

```
kubectl get deployment api -n metrics-app \
  -o jsonpath='{.spec.template.spec.containers[0].resources}' | python3 -m json.tool
```{{copy}}

## Check the current QoS class of each pod

```
kubectl get pods -n metrics-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}'
```{{copy}}

You should see:
- `frontend-*` pods: `Guaranteed` (requests == limits, but both are wrong)
- `api-*` pods: `Burstable` (limits > requests)

## Verify Goldilocks is NOT yet watching this namespace

```
kubectl get vpa -n metrics-app
```{{copy}}

Expected: `No resources found in metrics-app namespace.`

Goldilocks only creates VPA objects after you label the namespace. That's the next step.
