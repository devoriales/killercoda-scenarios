# What you built

| Step | What you did | The thing worth remembering |
| --- | --- | --- |
| 1 | Created and synced an Application | The Application lives in `argocd`, not in the namespace it deploys to |
| 2 | Constrained one with an AppProject | Rejections arrive as `.status.conditions`, not as a failed `kubectl apply` |
| 3 | Produced a Synced but Degraded app | Sync answers "does it match Git", health answers "does it work" |
| 4 | Built an app-of-apps | One Application can create others, and the tracking-id says who owns what |

## Five things to carry away

- **`Synced` is not a success signal.** It means the cluster matches Git. If Git describes
  something broken, Argo CD will make your cluster broken and report success.
- **`clusterResourceWhitelist: []` means nothing cluster-scoped**, not "unrestricted". It is
  the single most valuable line in an AppProject.
- **A pipeline that only checks `kubectl apply` exit codes will miss project rejections.**
  The object is created; the refusal comes later, as a condition.
- **The tracking-id annotation answers "who owns this?"** Reach for it whenever an app is
  `OutOfSync` with no visible diff.
- **`Progressing` lasts 600 seconds by default.** A stuck rollout looks like a slow one for
  ten minutes.

## Where to go next

**[Argo CD 3/3: Kustomize, Helm, and self-healing deployments](https://killercoda.com/devoriales/course/argocd/scenario-3-kustomize-helm-autosync)**
takes the same repo and deploys it four different ways, then turns on `selfHeal` and shows
it reverting a manual change within seconds.

If you have not done it, **[scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access)**
covers installing Argo CD, including the failure most guides skip past.

## The full course

These scenarios are the hands-on labs from
**[Argo CD for Beginners](https://devoriales.com/quiz/26/argo-cd-for-beginners-foundations-first-deployments)** on devoriales.com, a free
course that goes from what GitOps is through to multi-cluster deployments. Everything in it
is verified against a real cluster before it ships.

The repository you have been deploying from is public:
[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner).
