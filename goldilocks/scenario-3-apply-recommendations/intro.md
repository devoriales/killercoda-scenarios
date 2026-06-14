# Goldilocks Lab 3/3 — Apply Recommendations

The full stack is already running in this lab:
- VPA and Goldilocks are installed
- The `metrics-app` namespace is labeled and Goldilocks is managing it
- VPA recommendations are being computed

**Your task:** Read the recommendations, choose the right QoS strategy for each workload, and apply the changes — then verify the pods rolled out correctly.

By the end of this lab you will have:
- Patched `frontend` to **Guaranteed QoS** (reducing from 500m → 15m CPU)
- Patched `api` to **Burstable QoS** (increasing requests from 10m → 19m CPU with safe limits)
- Confirmed the QoS class of each pod

When you see the `$` prompt, VPA recommendations are ready.
