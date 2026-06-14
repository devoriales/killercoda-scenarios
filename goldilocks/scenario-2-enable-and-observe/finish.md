# Lab 2 Complete!

You have:
- Activated Goldilocks for the `metrics-app` namespace with a single label
- Watched VPA objects appear automatically within seconds
- Read VPA recommendations from the CLI

## Key Findings

The sample app has two common problems, both visible in the VPA data:

| Deployment | Problem | VPA target vs current |
|-----------|---------|----------------------|
| `frontend` | Over-provisioned | Target: ~15m CPU vs current: 500m CPU (33× too much) |
| `api` | Under-provisioned | Target: ~126m CPU vs current: 10m CPU (12× too little) |

## Key Points

- Goldilocks creates VPAs named `goldilocks-<deployment-name>`, all in `Off` mode
- VPA reports container recommendations by **container name** (e.g., `nginx`, `httpbin`), not deployment name
- The `upperBound` is unreliable for the first ~8 days — use `target` for resource requests

## Next Lab

**Lab 3: Apply Recommendations** — Take the numbers you just read and apply them to real deployments. Verify QoS class changes after the rollout.
