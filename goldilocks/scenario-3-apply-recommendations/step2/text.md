# Step 2: Apply Guaranteed QoS to the Frontend

The frontend (nginx) is over-provisioned. VPA recommends `~15m CPU / ~100Mi memory`. We'll apply **Guaranteed QoS** by setting requests equal to limits equal to the target.

## Check current state

```
kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].status.qosClass}'
```{{copy}}

Output: `Guaranteed` — but with wrong values (`500m / 512Mi`).

## Apply the patch

```
kubectl patch deployment frontend -n metrics-app --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"15m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"100Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"15m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"100Mi"}
]'
```{{copy}}

## Wait for the rollout

```
kubectl rollout status deployment/frontend -n metrics-app --timeout=90s
```{{copy}}

## Verify the new QoS class and resources

```
kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].status.qosClass}'
```{{copy}}

Expected: `Guaranteed` ✅

```
kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].spec.containers[0].resources}'
```{{copy}}

Expected: `{"limits":{"cpu":"15m","memory":"100Mi"},"requests":{"cpu":"15m","memory":"100Mi"}}`

## What changed

| | Before | After |
|-|--------|-------|
| CPU request | 500m | 15m |
| CPU limit | 500m | 15m |
| Memory request | 512Mi | 100Mi |
| Memory limit | 512Mi | 100Mi |
| QoS class | Guaranteed | Guaranteed (same class, right values) |
