# Done

Five boundaries, each enforced somewhere different, and each one demonstrated by watching it
refuse something.

| Step | What you learned | Key mechanism |
| --- | --- | --- |
| 1 | What an Application may deploy, and from where | `AppProject` sourceRepos, destinations, clusterResourceWhitelist |
| 2 | Who may act on it, and what the default leaks | `argocd-rbac-cm` policy.csv and policy.default |
| 3 | Where a tenant may declare Applications | `application.namespaces` plus `sourceNamespaces` |
| 4 | How a secret reaches Git without being readable | `kubeseal` and the Sealed Secrets controller |
| 5 | How to require a commit be authorised | `AppProject.spec.signatureKeys` |

## Worth carrying forward

- **Every Argo CD boundary is enforced at reconciliation, not at `kubectl apply`.** Every
  rejected object in this scenario was accepted by Kubernetes and refused seconds later in a
  status condition. A pipeline that checks only the apply exit code reports all of them as
  successes.
- **`policy.default: role:readonly` is the leak to check first.** It applies to everyone who
  authenticates, so a policy that carefully scopes a developer to one project still lets them
  read every other project until you set it to `""`.
- **`clusterResourceWhitelist: []` is what prevents privilege escalation.** Argo CD holds
  cluster-admin. Without that line, a tenant committing a ClusterRoleBinding gets it applied by
  a controller entitled to apply it.
- **Editing an AppProject does not re-queue its Applications.** The condition you are reading
  may predate your change by up to `timeout.reconciliation`, three minutes by default. Check the
  project's spec, then `argocd.argoproj.io/refresh=hard`, before doubting the change.
- **A missing status is worse than an error.** An Application in an unwatched namespace gets no
  status, no conditions and no events. If someone reports that their Application "does nothing
  at all", check which namespace it is in first.
- **base64 is an encoding.** `base64 -d` needs no key and no privilege. A SealedSecret is safe
  to commit because only the controller's private key decrypts it.
- **Back up the sealing key on the day you install the controller.** It is generated per cluster.
  Rebuild without it and every SealedSecret in your repository is undecryptable ciphertext that
  still applies without error.
- **Argo CD's multi-tenancy is cooperative, not adversarial.** It prevents mistakes and honest
  overreach. A tenant who can run a Job in their own namespace has all of Kubernetes available.
  For genuinely untrusted tenants the boundary is a cluster, not a project.

## What is next

You now have the boundaries. What is missing is knowing when any of it breaks: which metric
shows drift nobody is correcting, which component's log actually names the cause of a failed
render, and what to tune when there are thousands of Applications rather than five.

### Continue with the course

This lab is the hands-on half of **Modules 7 and 8** of
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

The modules behind this lab go further than a browser VM can: registering a second real cluster
and watching one Argo CD manage both, wiring SSO, and the RBAC model for teams rather than a
single demo account.

The runnable files are in
**[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner)**,
so you can clone and follow along instead of copying from a page.
