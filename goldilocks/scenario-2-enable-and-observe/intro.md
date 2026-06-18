# Goldilocks Lab 2/3 — Enable and Observe Recommendations

A sample application named `metrics-app` has been deployed in the background. It has **intentionally wrong resource settings**:

- **frontend** (nginx): over-provisioned at `500m CPU / 512Mi memory` — wastes cluster capacity
- **api** (httpbin): under-provisioned at `10m CPU / 32Mi memory` — will be CPU throttled under any load

Goldilocks, VPA, and metrics-server are already installed and running.

In this lab you will:
1. Inspect the sample app's current (broken) resource settings
2. Label the `metrics-app` namespace to activate Goldilocks
3. Read the first VPA recommendations from the CLI

The full stack (metrics-server, VPA, Goldilocks, and the sample app) installs
automatically and takes **~3-5 minutes**. You don't need to run anything to set it up —
the terminal shows the setup progress and Step 1 only opens once everything is up.
