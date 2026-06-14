# Step 3: Read VPA Recommendations

After ~60 seconds, the VPA recommender has enough data to produce recommendations. Let's read them.

## Check recommendation status

```
kubectl get vpa -n metrics-app
```

Wait until the `PROVIDED` column shows `True` for at least one VPA before continuing.

## Read the frontend recommendation

```
kubectl describe vpa goldilocks-frontend -n metrics-app
```

Look for the `Recommendation` section. The frontend runs nginx with very low CPU usage. You should see something like:

```
Container Name:  nginx
Lower Bound:
  Cpu:     15m
  Memory:  100Mi
Target:
  Cpu:     15m
  Memory:  100Mi
Upper Bound:
  Cpu:     ...
  Memory:  ...
```

Compare this to the current setting (`500m CPU / 512Mi memory`). The **target** of `15m` CPU is a **33× reduction** — this is over-provisioning at its most visible.

## Read the api recommendation

```
kubectl describe vpa goldilocks-api -n metrics-app
```

The api runs httpbin. The target CPU will be higher than the current request of `10m` — this deployment is **under-provisioned** and being throttled.

## Get all targets as JSON

```
kubectl get vpa -n metrics-app -o json | \
  python3 -c "
import json, sys
vpas = json.load(sys.stdin)
for vpa in vpas['items']:
    name = vpa['metadata']['name'].replace('goldilocks-', '')
    recs = vpa.get('status', {}).get('recommendation', {}).get('containerRecommendations', [])
    for r in recs:
        print(f'{name}/{r[\"containerName\"]}: target={r[\"target\"]}')
"
```

> **Note on upper bounds:** The `upperBound` values may be unrealistically large (e.g., thousands of millicores). VPA needs approximately 8 days of data to converge on accurate upper bounds. The `target` and `lowerBound` are much more reliable after just 1-2 hours.
