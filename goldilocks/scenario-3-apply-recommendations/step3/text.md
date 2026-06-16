# Step 3: Apply Burstable QoS to the Api

The api (httpbin) has variable load from the load-generator. We'll use **Burstable QoS**: a low request (VPA `lowerBound`) that saves cost at idle, with a reasonable limit that allows bursting.

## Strategy

- `requests` = VPA `lowerBound` ≈ `19m CPU / 100Mi memory`
- `limits` = 2× VPA `target` ≈ `250m CPU / 200Mi memory`

> **Why not use the dashboard's `upperBound` for limits?** The `upperBound` needs ~8 days of data to converge. Early values can be in the thousands of millicores, which is not useful as a real limit.

## Apply the patch

```
kubectl patch deployment api -n metrics-app --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"19m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"100Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"250m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"200Mi"}
]'
```{{copy}}

## Wait for the rollout

```
kubectl rollout status deployment/api -n metrics-app --timeout=90s
```{{copy}}

## Verify QoS is Burstable

```
kubectl get pod -n metrics-app -l app=api \
  -o jsonpath='{.items[0].status.qosClass}'
```{{copy}}

Expected: `Burstable` ✅ (because `requests < limits`)

## Summary: QoS classes for all pods

```
kubectl get pods -n metrics-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}'
```{{copy}}

Expected:
- `api-*` pods → `Burstable`
- `frontend-*` pods → `Guaranteed`
- `load-generator-*` → `Burstable`

## Important: commit changes to your manifests

The `kubectl patch` command updated the running deployment, but Kubernetes uses the deployment spec when rescheduling pods. Always copy the new values into your deployment YAML files and commit them to version control. Otherwise, the next deploy will revert to the old values.
