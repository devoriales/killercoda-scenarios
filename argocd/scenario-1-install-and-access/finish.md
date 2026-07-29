# Done

You installed Argo CD 3.4.5 the way you would on a real cluster, including the part that
usually goes unnoticed.

| Step | What you learned | Key command |
| --- | --- | --- |
| 1 | Client-side apply cannot write the ApplicationSet CRD | `kubectl apply --server-side --force-conflicts` |
| 2 | `kubectl wait` passing is not proof of a healthy install | `kubectl get pods -n argocd` |
| 3 | Confirm which build is answering, not just that something is | `curl -sk .../api/version` |
| 4 | Rotation leaves the bootstrap credential behind | `kubectl delete secret argocd-initial-admin-secret` |

## Worth carrying forward

- **Pin the version in the URL.** `stable` is a moving branch, so applying it twice
  installs two different versions and nothing records which you got.
- **Server-side apply is the default for Argo CD**, not a workaround. The ApplicationSet
  CRD is about 374 KB against a 262144 byte annotation cap, and no amount of retrying
  client-side apply will fit it.
- **A Deployment is `Available` with one replica up.** On a node evicting pods, one
  survivor is enough for `kubectl wait` to report success over a broken install.
- **Two of the seven workloads do nothing on a default install.** Dex has no `dex.config`
  and notifications has no triggers. That is precisely what Argo CD Core leaves out.
- **`argocd-initial-admin-secret` survives rotation** holding the retired password in
  plaintext. Delete it, and only after the new password is confirmed.

## What is next

You have Argo CD running but nothing deployed through it. The next thing to learn is the
`Application` resource: what its fields mean, how sync status differs from health status,
and why an app can be `Synced` and still broken.

### Continue with the course

This lab is **Module 2** of
**[Argo CD for Beginners: Foundations and First Deployments](https://devoriales.com/quiz/26/argo-cd-for-beginners-foundations-first-deployments)**
on devoriales.com. It is free, and it covers:

| Module | What it covers |
| --- | --- |
| 1 | GitOps and Argo CD foundations: drift, push versus pull, architecture |
| 2 | Installation and first setup, including everything in this lab |
| 3 | Core concepts: the `Application` resource, `AppProject`, sync versus health |
| 4 | Deploying with plain YAML, Kustomize, Helm, and OCI charts |

The course runs on a local k3d cluster rather than a browser VM, which is the setup you
keep for the later modules. Every command in it was executed before it was published.

The runnable files are in
**[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner)**,
so you can clone and follow along instead of copying from a page.
