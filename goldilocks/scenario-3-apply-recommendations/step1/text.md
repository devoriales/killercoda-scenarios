# Step 1: Read Recommendations and Choose a Strategy

## Get the current recommendations

```
kubectl get vpa -n metrics-app
```{{copy}}

Confirm `PROVIDED=True` for at least the `goldilocks-frontend` and `goldilocks-api` VPAs before continuing.

## Read the frontend target

```
kubectl get vpa goldilocks-frontend -n metrics-app \
  -o jsonpath='{.status.recommendation.containerRecommendations[0].target}'
```{{copy}}

The target CPU will be around `15m` — far below the current `500m`. This is over-provisioning.

## Read the api target

```
kubectl get vpa goldilocks-api -n metrics-app \
  -o jsonpath='{.status.recommendation.containerRecommendations[0].target}'
```{{copy}}

The target CPU will be significantly above the current `10m` request. This is under-provisioning.

## Choosing a QoS Strategy

| Deployment | Workload type | Recommended QoS | Reason |
|-----------|--------------|-----------------|--------|
| `frontend` | nginx, static content, predictable | **Guaranteed** | CPU usage is stable and very low; Guaranteed gives consistent scheduling |
| `api` | httpbin, variable traffic | **Burstable** | Requests low at idle, can burst during load spikes |

For **Guaranteed**: set `requests == limits == VPA target`
For **Burstable**: set `requests = lowerBound`, `limits = 2-3× target` (don't use raw upperBound yet — it needs 8 days to converge)

## Read the lowerBound for api (used for Burstable requests)

```
kubectl get vpa goldilocks-api -n metrics-app \
  -o jsonpath='{.status.recommendation.containerRecommendations[0].lowerBound}'
```{{copy}}
