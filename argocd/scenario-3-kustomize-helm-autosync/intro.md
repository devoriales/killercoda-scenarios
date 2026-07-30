# Four ways to deploy, and one that fixes itself

Argo CD does not have a plugin system for deployment tools in the way you might expect. It
looks at the directory you point it at and works out what to do:

- a directory of YAML files gets applied as-is
- a directory containing `kustomization.yaml` gets rendered with Kustomize
- a directory containing `Chart.yaml` gets rendered with Helm
- a chart repository or OCI registry gets pulled, then rendered with Helm

**There is no `type:` field to set.** That single design decision explains a lot of Argo CD's
behaviour, and this scenario walks through the first three from the same repository so you
can see how little changes between them.

Then you turn on the setting that makes GitOps mean something: `selfHeal`. You will scale a
Deployment by hand, watch Argo CD put it back, and understand why that breaks a habit most
operators have.

In the next 25 minutes you will:

- Deploy a directory of plain YAML and see the ordering Argo CD imposes for free
- Run one Kustomize base as two environments with different replica counts
- Deploy a Helm chart and prove that **no Helm release exists**, which surprises most Helm users
- See exactly what the repo-server rendered, before it is applied
- Turn on auto-sync and self-heal, then watch a manual `kubectl scale` get reverted

## What is already set up

Argo CD 3.4.5 is installed and running, and the `argocd` CLI is ready. Installing it is
[scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access);
building your first Application and understanding its two status columns is
[scenario 2](https://killercoda.com/devoriales/course/argocd/scenario-2-applications-and-projects).
Neither is required before this one.

The CLI is in **core mode**, talking to the Kubernetes API directly, so there is no
port-forward to keep alive and no password to paste.

Manifests are in `/root/manifests/`, and everything is deployed from the public repo
[devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner).

## Part of a course

This scenario covers Module 4 of the free
[Argo CD for Beginners](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops) course on devoriales.com, which
continues into sync waves, ApplicationSets, RBAC, secrets and multi-cluster.

Let's deploy the same application four different ways.
