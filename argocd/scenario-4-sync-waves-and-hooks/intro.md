# Order, and the work that happens around a deploy

Argo CD applies your manifests in a built-in kind order: namespaces before workloads, CRDs
before most things. That is enough surprisingly often, and then one day it is not.

It cannot express any of these:

- **Run the database migration, and do not start the app until it has finished.** Both are workloads, so kind ordering has no opinion.
- **Install the operator before the custom resources that need its CRDs**, or you get `no matches for kind`.
- **Run a smoke test, but only once the app is actually serving.**

That is what **sync waves** are for. And the migration itself raises a second question: it is
not really part of your application, so should it live in the cluster forever? That is what
**hooks** are for.

In the next 25 minutes you will:

- Gate a Deployment on a migration Job with sync waves, and **prove the ordering from creation timestamps** rather than trusting a duration
- Watch `PreSync` and `PostSync` hooks run around a sync, and see why a hook is a task rather than desired state
- Run three identical hooks with three different deletion policies and discover which one is the default, by measurement
- Block a sync entirely with a **sync window**, then let a human through while automation stays blocked

## What is already set up

Argo CD 3.4.5 is installed and running, and the `argocd` CLI is ready in core mode, so there
is no port-forward to keep alive and no password to paste. Installing Argo CD is
[scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access).

The Application and AppProject manifests are in `/root/manifests/`. The workloads they
deploy come from the public repo
[devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner), so you are
watching Argo CD pull from Git exactly as it would in production.

## Part of a course

This scenario covers Module 5 of the free
[The Complete Argo CD Course](https://devoriales.com/quiz/26/the-complete-argo-cd-course-gitops-basics-to-production)
course on devoriales.com, which continues into ApplicationSets, multi-tenancy, security and
a capstone platform.

Let's make Argo CD wait for something.
