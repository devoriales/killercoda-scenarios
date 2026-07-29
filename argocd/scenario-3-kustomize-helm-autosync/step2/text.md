# Kustomize: one base, two environments

Plain YAML stops scaling the moment you need the same application in two environments with
small differences. Copying the directory works until the copies drift, which they always do.

Kustomize keeps one set of manifests and expresses the differences as patches. Argo CD needs
**no configuration at all** to use it: if the directory contains a `kustomization.yaml`, the
repo-server renders it with Kustomize.

The layout in the repository:

```
02-kustomize/
├── base/
│   ├── deployment.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/kustomization.yaml
    └── prod/kustomization.yaml
```

The base is a complete, deployable Deployment with one replica. Dev takes it as-is with a
name prefix. Prod takes the same base and patches the replica count to three. Neither
overlay copies the base; both reference it.

## Point at the overlay, not the base

`cat /root/manifests/02-kustomize/kustom-prod-application.yaml`{{exec}}

The `path` ends in `overlays/prod`. Pointing at `base` deploys the unpatched base, which is
a valid thing to do and almost never what you meant. The overlay reaches back into the base
through its `resources` entry, so both directories end up in the render even though only one
is named.

Deploy both environments:

`kubectl apply -f /root/manifests/02-kustomize/kustom-dev-application.yaml -f /root/manifests/02-kustomize/kustom-prod-application.yaml`{{exec}}

`argocd app sync kustom-dev kustom-prod`{{exec}}

Wait a few seconds, then compare them:

`kubectl get deploy -n demo -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas' | grep kustom`{{exec}}

```
dev-kustom    1     1
prod-kustom   3     3
```

**One base, two overlays, two different outcomes.** Changing the container image now means
editing `base/deployment.yaml` once, and both environments pick it up on their next sync.

## See exactly what will be applied

`argocd app manifests kustom-prod`{{exec}}

That is the rendered output, before anything touches the cluster. It renders through the
**repo-server**, using the Kustomize binary inside that pod:

`kubectl exec -n argocd deploy/argocd-repo-server -- kustomize version`{{exec}}

```
v5.8.1
```

This matters more than it looks. If your local `kustomize build` disagrees with
`argocd app manifests`, the versions differ, and **the repo-server's output is the one that
counts**. Your laptop's Kustomize never renders anything Argo CD applies.

## The failure mode to expect

A patch that silently matches nothing. Kustomize patches select by `target`, and a target
naming a resource that does not exist is **not an error**:

```yaml
- target: {kind: Deployment, name: kustomm}   # typo
```

Kustomize renders happily, the patch is skipped, and you get base values with no warning at
all. The symptom is prod quietly running one replica while the overlay clearly says three.

`argocd app manifests` is how you catch it. Check the rendered output rather than trusting
the patch to have applied.
