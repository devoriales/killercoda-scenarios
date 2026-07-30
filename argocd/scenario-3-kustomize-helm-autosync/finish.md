# What you built

| Step | What you deployed | The thing worth remembering |
| --- | --- | --- |
| 1 | A directory of plain YAML | The directory is the unit, and Argo CD orders kinds for you |
| 2 | One Kustomize base as two environments | The repo-server's Kustomize is the one that counts |
| 3 | A Helm chart | Argo CD templates charts; there is no Helm release |
| 4 | An app with `automated` and `selfHeal` | A manual change gets reverted in seconds |

Four deployment styles, one repository, and **not one line of configuration telling Argo CD
which was which**. It reads the directory and decides.

## Five things to carry away

- **There is no `type:` field.** A `kustomization.yaml` makes it Kustomize, a `Chart.yaml`
  makes it Helm, and neither makes it plain YAML.
- **`helm list` is empty on purpose.** Argo CD runs `helm template`, so rollback is
  `git revert` and history is `git log`.
- **The repo-server renders, not your laptop.** When local output disagrees with
  `argocd app manifests`, the repo-server's version is the one that ships.
- **A Kustomize patch that matches nothing is not an error.** It renders silently with base
  values, and `argocd app manifests` is how you catch it.
- **`selfHeal` breaks scaling by hand during an incident.** That is a process change, not a
  tooling one, and it is better to know before 3 a.m.

## Where to go next

**[Argo CD 4: Sync Waves, Hooks, and Sync Windows](https://killercoda.com/devoriales/course/argocd/scenario-4-sync-waves-and-hooks)**
makes Argo CD wait: it gates a Deployment on a database migration, runs PreSync and PostSync
hooks, and blocks a sync entirely with a sync window.

If you have not done them:

- **[Scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access)**: install Argo CD, including the failure most guides skip past
- **[Scenario 2](https://killercoda.com/devoriales/course/argocd/scenario-2-applications-and-projects)**: Applications, AppProjects, and an app that is Synced and broken at the same time

## The full course

These scenarios are the hands-on labs from
**[Argo CD for Beginners](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops)** on devoriales.com, a free
course that goes from what GitOps is through to multi-cluster deployments. Every command and
output in it is verified against a real cluster before it ships.

The next modules cover sync waves and hooks, ApplicationSets that generate Applications from
a list, RBAC and SSO, and secrets management.

The repository you have been deploying from is public:
[github.com/devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner).
