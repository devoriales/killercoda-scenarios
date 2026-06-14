# Lab 3 Complete — Goldilocks Series Finished!

You have completed the full Goldilocks hands-on series.

## What You Accomplished

| Lab | What you did |
|-----|-------------|
| Lab 1 | Installed VPA and Goldilocks via Helm with the correct image registry |
| Lab 2 | Activated Goldilocks for a namespace, watched VPA objects appear, read raw recommendations |
| Lab 3 | Applied Guaranteed QoS (frontend: 33× CPU reduction) and Burstable QoS (api: corrected under-provisioning) |

## Key Takeaways

1. **Goldilocks is advisory** — it uses VPA in `Off` mode and never touches your pods
2. **One label activates it** — `goldilocks.fairwinds.com/enabled=true` on a namespace
3. **The 8-day rule** — trust `target` for requests early on; wait for upper bounds to converge before using them as limits
4. **QoS choice matters** — Guaranteed for predictable latency-sensitive workloads, Burstable for variable/batch workloads
5. **Always commit changes** — `kubectl patch` updates the running pod, but the deployment spec must be updated in your manifests for changes to persist

## Next Steps

- Read the full tutorial at the devoriales.com Goldilocks tutorial
- Enable Goldilocks on your own cluster with `on-by-default` mode for broad coverage
- Set up a weekly CI job to detect resource drift and open PRs automatically
