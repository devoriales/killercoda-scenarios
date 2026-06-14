# Step 3: Verify the Installation

## Check all components

Run each verification command and compare to the expected output.

**VPA pods:**
```
kubectl get pods -n vpa
```
Expected: three pods (recommender, updater, admission-controller) all `1/1 Running`.

**Goldilocks pods:**
```
kubectl get pods -n goldilocks
```
Expected: two pods (controller and dashboard) both `1/1 Running`.

**Goldilocks dashboard service:**
```
kubectl get svc -n goldilocks
```
Expected: `goldilocks-dashboard` service with type `ClusterIP` on port `80`.

**Confirm image registry:**
```
kubectl get pods -n goldilocks \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```
Both lines should start with `us-docker.pkg.dev/fairwinds-ops/oss/goldilocks`.

**Helm releases:**
```
helm list -A
```
You should see `vpa` (namespace: vpa) and `goldilocks` (namespace: goldilocks), both with STATUS `deployed`.

## Preview the dashboard (optional)

You can preview the dashboard, but there are no labeled namespaces yet — it will show "No namespaces found." That comes in Lab 2.

```
kubectl -n goldilocks port-forward svc/goldilocks-dashboard 8080:80 &
curl -sL http://localhost:8080/namespaces | grep -o "namespaceList.*" | head -1
```
