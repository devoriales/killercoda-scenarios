# What you built

| Step | What you did | The thing worth remembering |
| --- | --- | --- |
| 1 | Gated a Deployment on a migration Job | Waves **wait** for Healthy; kind ordering only sequences |
| 2 | Ran PreSync and PostSync hooks | A hook is a task, so deleting a completed one leaves the app `Synced` |
| 3 | Compared three deletion policies | `BeforeHookCreation` is the default, proven by timestamps |
| 4 | Blocked a sync with a window | Deny always wins, and `manualSync` is the on-call escape hatch |

## Five things to carry away

- **Kind ordering cannot wait.** It applies namespaces before workloads and has no opinion about a Job versus a Deployment, and never waits for readiness. That gap is what waves fill.
- **Use negative waves for prerequisites.** `-3` namespaces, `-2` CRDs, `-1` operators, and your application stays at the default `0` needing no annotation.
- **Wave or hook: does the cluster need to contain it?** A migration is work, so it is a hook. A ConfigMap is a thing, so it is a wave.
- **A hook with no deletion policy does not accumulate.** It behaves as `BeforeHookCreation`, leaving exactly one stale Job per hook. `HookSucceeded` is tidier and costs you the logs.
- **A stuck wave has no error.** It reports `Progressing` forever because nothing failed. Look for the wave that never became Healthy.

## The real-world orderings this applies to

Beyond the migration example, the cases you will actually meet:

- **CRDs before custom resources.** Apply a `Certificate` before cert-manager's CRD exists and Kubernetes itself tells you: `ensure CRDs are installed first`.
- **Operators before their CRs.** Prometheus Operator before a `ServiceMonitor`, Strimzi before a `KafkaTopic`.
- **Issuer, then Certificate, then Ingress.** Otherwise users see a browser warning while the TLS Secret does not exist yet.
- **Secrets before the workloads that mount them.** Especially when a controller produces the Secret, such as a SealedSecret being decrypted.

## Where to go next

**[Argo CD 5: ApplicationSets and Progressive Syncs](https://killercoda.com/devoriales/course/argocd/scenario-5-applicationsets)**
generates Applications from a list, a Git repository or a cluster registry, and rolls changes
out environment by environment.

If you have not done them:

- **[Scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access)**: install Argo CD, including the failure most guides skip
- **[Scenario 2](https://killercoda.com/devoriales/course/argocd/scenario-2-applications-and-projects)**: Applications, AppProjects, and Synced but broken
- **[Scenario 3](https://killercoda.com/devoriales/course/argocd/scenario-3-kustomize-helm-autosync)**: Kustomize, Helm, and self-healing

## The full course

These scenarios are the hands-on labs from
**[Argo CD for Beginners: From First Sync to Production GitOps](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops)**
on devoriales.com, a free twelve-module course that ends with a multi-tenant platform
bootstrapping itself from a single file. Every command in it was executed against a real
cluster before it was written down.

The repository you have been deploying from is public:
[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner).
