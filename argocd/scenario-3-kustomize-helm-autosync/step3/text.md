# Helm, without a Helm release

Argo CD deploys Helm charts in a way that surprises most Helm users. Get the mechanism
straight first, because almost every confusing thing about Helm under Argo CD follows from
it.

**Argo CD does not run `helm install`. It runs `helm template` in the repo-server and
applies the output.**

There is no Helm release. No release history, no `helm rollback`, no release secret in the
target namespace. Argo CD takes the rendered manifests and treats them exactly like the
plain YAML from step 1.

## Prove it

`cat /root/manifests/03-helm/helm-demo-application.yaml`{{exec}}

Note `helm.valuesObject`, which takes YAML inline and keeps values in the same reviewable
file as the rest of the Application.

`kubectl apply -f /root/manifests/03-helm/helm-demo-application.yaml`{{exec}}

`argocd app sync helm-demo`{{exec}}

The workload is running:

`kubectl get deploy helm-demo -n demo -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas'`{{exec}}

```
helm-demo   2
```

Now ask Helm what it knows about it:

`helm list -n demo`{{exec}}

```
NAME	NAMESPACE	REVISION	UPDATED	STATUS	CHART	APP VERSION
```

**Empty.** Helm has never heard of this workload. Ownership sits with Argo CD instead:

`kubectl get deploy helm-demo -n demo -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'`{{exec}}

```
helm-demo:apps/Deployment:demo/helm-demo
```

This is a deliberate design decision, not a missing feature. A Helm release is state stored
in the cluster, and state in the cluster is exactly what GitOps is trying to eliminate.
Rollback becomes `git revert` and history becomes `git log`.

## Four ways to supply values

| Field | Takes | Use when |
| --- | --- | --- |
| `valuesObject` | inline YAML | a handful of overrides, kept with the Application |
| `valueFiles` | paths in the repo | per-environment files like `values-prod.yaml` |
| `parameters` | explicit key/value pairs | one or two scalars, like an image tag |
| `values` | a YAML **string** | legacy; `valuesObject` is easier to read |

Precedence runs chart defaults, then `valueFiles` in order, then `values`/`valuesObject`,
then `parameters` last. When an override "does not work", it is usually being beaten by
something later in that list.

## The version that renders your chart

`kubectl exec -n argocd deploy/argocd-repo-server -- helm version --short`{{exec}}

```
v3.19.4+g7cfb6e4
```

If `helm template` on your laptop produces output Argo CD does not, compare this number with
your own before suspecting anything else.

## Charts from outside Git

A chart does not have to live in your repository:

```yaml
source:
  repoURL: https://prometheus-community.github.io/helm-charts
  chart: kube-prometheus-stack
  targetRevision: 65.1.0
```

`targetRevision` is a **chart version** here, not a Git ref. Putting `main` in it produces a
version-not-found error, and that is the single most common mistake when moving from a Git
source to a chart repository.

Charts published to an OCI registry work the same way, with `repoURL` set to the registry
and namespace and **no `oci://` prefix**. That prefix belongs in `helm pull` commands, not
in `repoURL`.

## The failure mode to expect

Someone runs `helm install` for the same chart into the same namespace Argo CD is already
managing. Now a Helm release and an Argo CD Application both claim the same resources, each
reverting the other, and `helm list` shows a release Argo CD does not know exists.

Pick one owner per workload.
