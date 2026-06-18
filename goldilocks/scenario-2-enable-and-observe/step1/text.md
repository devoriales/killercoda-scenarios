# Step 1: Explore the Sample App

The lab environment (metrics-server, VPA, Goldilocks, sample app) is prepared
automatically — this step only opens once everything is up, so you can start right away.

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
