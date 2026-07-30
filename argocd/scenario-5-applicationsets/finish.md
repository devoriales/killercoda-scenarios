# What you built

| Step | What you did | The thing worth remembering |
| --- | --- | --- |
| 1 | Generated three Applications from one object | The owner reference means deleting the ApplicationSet deletes all of them |
| 2 | Discovered Applications from folders and clusters | `clusters: {}` produces `cl-in-cluster` from **zero** cluster secrets |
| 3 | Produced a cross product with matrix | Do the multiplication before you apply it |
| 4 | Enabled progressive syncs | Off by default, and a `RollingSync` strategy is then silently ignored |

## Five things to carry away

- **Every generator produces the same shape**: a list of parameter maps. List, Git, Cluster, Matrix and SCM Provider differ only in where those maps come from.
- **The template name must contain a parameter.** Without one you get a single Application rewritten once per element, and no error to tell you.
- **`kubectl delete applicationset` is a fleet-wide deletion.** With `prune: true` it takes the workloads too. `preserveResourcesOnDeletion` and `applicationsetcontroller.policy: create-update` are the mitigations.
- **An empty generator result is not an error.** It means zero Applications, so every Application it previously created is removed. An expired SCM token or a renamed branch can cause it.
- **A silently ignored feature is worse than a rejected one.** Progressive syncs taught you to check the flag reached the controller, not just the ConfigMap.

## Choosing a generator

| Generator | Source of truth | Reach for it when |
| --- | --- | --- |
| `list` | a list you maintain | the set is stable and you want it reviewable in the diff |
| `git` directories or files | your repository layout | apps are added by adding folders |
| `clusters` | registered clusters | the same app belongs on every cluster |
| `matrix` | two generators combined | you genuinely want every combination |
| `merge` | two generators, by key | "all of these, but prod is different" |
| `scmProvider` | the Git host's API | teams onboard themselves by creating repositories |

The honest default for a small stable set is a **list**, because the list is the documentation
and adding prod is a reviewable one-line diff rather than a directory quietly appearing.

## Where to go next

**[Argo CD 6: Multi-Cluster, RBAC, and Multi-Tenancy](https://killercoda.com/devoriales/course/argocd/scenario-6-multicluster-and-rbac)**
registers a second cluster, builds RBAC that actually holds, and gives a tenant its own
namespace without any access to `argocd`.

If you have not done them:

- **[Scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access)**: install Argo CD, including the failure most guides skip
- **[Scenario 2](https://killercoda.com/devoriales/course/argocd/scenario-2-applications-and-projects)**: Applications, AppProjects, and Synced but broken
- **[Scenario 3](https://killercoda.com/devoriales/course/argocd/scenario-3-kustomize-helm-autosync)**: Kustomize, Helm, and self-healing
- **[Scenario 4](https://killercoda.com/devoriales/course/argocd/scenario-4-sync-waves-and-hooks)**: sync waves, hooks, and sync windows

## The full course

These scenarios are the hands-on labs from
**[Argo CD for Beginners: From First Sync to Production GitOps](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops)**
on devoriales.com, a free twelve-module course that ends with a multi-tenant platform
bootstrapping itself from a single file. Every command in it was executed against a real
cluster before it was written down.

The repository you have been deploying from is public:
[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner).
