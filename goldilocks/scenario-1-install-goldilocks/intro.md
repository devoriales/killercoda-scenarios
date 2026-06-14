# Goldilocks Lab 1/3 — Install Goldilocks and VPA

Goldilocks is a tool by Fairwinds that uses the Kubernetes **Vertical Pod Autoscaler (VPA)** to recommend right-sized resource requests and limits for your deployments.

In this lab you will:
1. Install VPA — the engine that collects resource usage data
2. Install Goldilocks via Helm — the controller and dashboard that surface VPA recommendations
3. Verify both are running correctly

**The cluster is already running.** Helm and the metrics-server are being installed in the background. When the environment is ready you will see a `$` prompt.

> **Note:** This lab installs Goldilocks v4.15.1, which uses the `us-docker.pkg.dev/fairwinds-ops/oss/goldilocks` image registry. The old `quay.io/fairwinds/goldilocks` registry was deprecated in v4.15.0.
