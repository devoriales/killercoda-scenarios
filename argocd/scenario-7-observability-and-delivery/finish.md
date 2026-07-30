# Done

Five failures and two layers, each one produced on purpose so you have seen it before it happens
to you.

| Step | What you learned | Where the answer was |
| --- | --- | --- |
| 1 | Ownership conflicts never resolve by syncing | a tracking-id diff and `SharedResourceWarning` |
| 2 | The component reporting a failure is often relaying it | repo-server, `grpc.method=GenerateManifest` |
| 3 | Which drift is worth an alert | `argocd_app_info{sync_status="OutOfSync", autosync_enabled="false"}` |
| 4 | A paused canary is neither healthy nor broken | Application health `Suspended` |
| 5 | Root keeps everything else current | `platform-root`, alerted on by name |

## Worth carrying forward

- **A diff whose only content is a tracking-id means ownership, not content.** Two Applications
  overlap and will trade that annotation forever. Only the app that **lost** the resource reports
  `SharedResourceWarning`; the winner is `Synced`, `Healthy` and silent.
- **Count error lines before reading any.** The application controller logged zero and the
  repo-server logged one. Whoever produced the value knows why it is wrong.
- **`authentication required` can mean the repository does not exist.** Git will not confirm
  whether a private repo exists, so it asks for credentials instead. Check the spelling before
  hunting a credential problem.
- **`autosync_enabled="false"` is what makes a drift alert actionable.** Without it you page on
  every transient `OutOfSync` and everyone learns to ignore the alert.
- **Confirm a metric name exists before alerting on it.** `argocd_app_reconciliation_queue` is a
  reasonable guess and returns nothing, which is indistinguishable from a healthy queue. The real
  name is `workqueue_depth{name="app_reconciliation_queue"}`.
- **A paused canary reports `Suspended`, not `Progressing`.** Being neither `Healthy` nor
  `Degraded` is what makes `RollingSync` wait and keeps pagers quiet. Never alert on "not Healthy"
  on a cluster running canaries.
- **An automatic rollback is temporary** until you revert the commit, and `selfHeal` can undo it.
- **Alert on the root Application by name.** If root stops reconciling, everything below it goes
  stale rather than red, and your other alerts quietly stop meaning anything.
- **A child Application stuck at `OutOfSync` / `Missing` with empty conditions** is almost always
  a project restriction. Look in `status.operationState.syncResult`, and clear the retrying
  operation with `argocd app terminate-op` before re-syncing.

## Continue with the course

This lab is the hands-on half of **Modules 10, 11 and 12** of
**[Argo CD for Beginners: From First Sync to Production GitOps](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops)**
on devoriales.com. It is free, and complete: twelve modules, from what GitOps is through to a
multi-tenant platform that bootstraps itself from a single file.

| Modules | What they cover |
| --- | --- |
| 1 to 2 | GitOps foundations, then installing Argo CD on a pinned local cluster |
| 3 to 4 | Applications and AppProjects, then deploying with plain YAML, Kustomize, Helm and OCI charts |
| 5 to 6 | Sync waves, hooks and windows, then ApplicationSets and progressive syncs |
| 7 to 8 | Multi-cluster, RBAC and SSO, then secrets, signed commits and supply chain |
| 9 to 12 | The Source Hydrator, observability, progressive delivery, and a capstone platform |

The modules behind this lab go further than a browser VM can: notifications wired to a real
service, the Source Hydrator committing rendered manifests back to Git, and the controller tuning
that matters at thousands of Applications rather than five.

### The earlier labs

- **[Scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access)**: install Argo CD, including the failure most guides skip
- **[Scenario 2](https://killercoda.com/devoriales/course/argocd/scenario-2-applications-and-projects)**: Applications, AppProjects, and Synced but broken
- **[Scenario 3](https://killercoda.com/devoriales/course/argocd/scenario-3-kustomize-helm-autosync)**: Kustomize, Helm, and self-healing
- **[Scenario 4](https://killercoda.com/devoriales/course/argocd/scenario-4-sync-waves-and-hooks)**: sync waves, hooks, and sync windows
- **[Scenario 5](https://killercoda.com/devoriales/course/argocd/scenario-5-applicationsets)**: ApplicationSets and progressive syncs
- **[Scenario 6](https://killercoda.com/devoriales/course/argocd/scenario-6-tenancy-and-security)**: multi-tenancy, RBAC, sealed secrets and signed commits

The runnable files are in
**[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner)**.
