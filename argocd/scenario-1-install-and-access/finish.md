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

You have Argo CD running but nothing deployed through it. That is the next scenario:

**[Argo CD 2: Applications, Projects, and the Two Statuses That Matter](https://killercoda.com/devoriales/course/argocd/scenario-2-applications-and-projects)**
covers the `Application` resource, locking one down with an `AppProject`, and why an app can
be `Synced` and broken at the same time.

**[Argo CD 3: Kustomize, Helm, and Deployments That Fix Themselves](https://killercoda.com/devoriales/course/argocd/scenario-3-kustomize-helm-autosync)**
deploys the same repository four different ways, then turns on self-heal.

### Continue with the course

This lab is the hands-on half of **Module 2** of
**[Argo CD for Beginners: From First Sync to Production GitOps](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops)**
on devoriales.com. It is free, and complete: twelve modules and sixty lessons, from what
GitOps is through to a multi-tenant platform that bootstraps itself from a single file.

| Modules | What they cover |
| --- | --- |
| 1 to 2 | GitOps foundations, then installing Argo CD on a pinned local cluster |
| 3 to 4 | Applications and AppProjects, then deploying with plain YAML, Kustomize, Helm and OCI charts |
| 5 to 6 | Sync waves, hooks and windows, then ApplicationSets and progressive syncs |
| 7 to 8 | Multi-cluster, RBAC and SSO, then secrets, signed commits and supply chain |
| 9 to 12 | The Source Hydrator, observability, progressive delivery, and a capstone platform |

The course runs on a local k3d cluster rather than a browser VM, which is the setup you
keep for the later modules. Every command in it was executed before it was published.

The runnable files are in
**[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner)**,
so you can clone and follow along instead of copying from a page.
