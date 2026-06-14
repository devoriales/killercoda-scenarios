# Lab 1 Complete!

You have successfully installed:

- **VPA** (Vertical Pod Autoscaler) — the engine that collects resource usage and generates recommendations
- **Goldilocks** — the controller and dashboard that surface VPA recommendations in a usable form

## Key Points

- Goldilocks uses the `us-docker.pkg.dev/fairwinds-ops/oss/goldilocks` registry (not the deprecated `quay.io` path)
- Goldilocks always uses VPA in `Off` mode — it never evicts or restarts your pods
- The dashboard shows "No namespaces found" until you label a namespace with `goldilocks.fairwinds.com/enabled=true`

## Next Lab

**Lab 2: Enable and Observe** — Deploy a sample application with intentionally wrong resource settings, activate Goldilocks for the namespace, and read your first recommendations.
