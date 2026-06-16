# Step 2: Label the Namespace to Activate Goldilocks

Goldilocks is opt-in per namespace. A single label is all it takes.

## Add the label

```
kubectl label namespace metrics-app goldilocks.fairwinds.com/enabled=true
```{{copy}}

## Confirm the label was applied

```
kubectl get namespace metrics-app --show-labels
```{{copy}}

Look for `goldilocks.fairwinds.com/enabled=true` in the output.

## Watch VPA objects appear

Within 5-10 seconds, the Goldilocks controller will detect the label and create a `VerticalPodAutoscaler` object for each Deployment in the namespace.

```
kubectl get vpa -n metrics-app --watch
```{{copy}}

You should see entries appear for `goldilocks-api`, `goldilocks-frontend`, and `goldilocks-load-generator`. Press **Ctrl+C** once they appear.

Notice:
- All VPAs have `MODE: Off` — Goldilocks never evicts your pods
- The `PROVIDED` column starts as empty, then changes to `True` as recommendations arrive (~60 seconds)

## Inspect a Goldilocks-created VPA

```
kubectl get vpa goldilocks-api -n metrics-app -o yaml | head -30
```{{copy}}

Note the labels `creator: Fairwinds` and `source: goldilocks` — these identify VPAs managed by Goldilocks vs ones you create manually.
