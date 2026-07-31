# Generating Applications instead of writing them

Scenario 2 built an app-of-apps: one Application whose directory holds other Application
manifests. It works, and it stores **one file per Application**.

Then you add a fourth environment and notice you are copying a file and changing one word in
it. Then a fifth. Then someone adds a service and has to copy five files. The problems arrive
in a predictable order:

- **copies drift**, because someone updates the sync policy in two of the three
- **adding a thing is a mechanical edit**, which means a review nobody reads properly
- **there is no list**, so nothing in Git states which environments exist. It is implied by
  which files happen to be there

An `ApplicationSet` replaces the copies with a **generator plus a template**. The generator
produces a set of parameter maps; the template is rendered once per map.

In the next 25 minutes you will:

- Generate three Applications from one object, and see the owner reference that means **deleting the ApplicationSet deletes all of them**
- Discover Applications from repository folders, and find out what `clusters: {}` produces on a single-cluster install (the answer surprises people)
- Produce a **cross product** with a matrix generator, and do the multiplication before applying it
- Turn on progressive syncs, and watch step 2 sit at `Waiting` until step 1 is Healthy

## What is already set up

Argo CD 3.4.5 is installed and running, with the `argocd` CLI in core mode, so there is no
port-forward to keep alive and no password to paste.

The ApplicationSet manifests are in `/root/manifests/`. The workloads they generate
Applications for come from the public repo
[devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner), which holds three
environment folders under `module-06-applicationsets/03-git-generator/envs/`.

**Progressive syncs are deliberately left off.** Step 4 is about discovering that, because a
`RollingSync` strategy on a stock install is silently ignored rather than rejected, and that
is worth meeting once in a lab rather than in production.

## Part of a course

This scenario covers Module 6 of the free
[The Complete Argo CD Course](https://devoriales.com/quiz/26/the-complete-argo-cd-course-gitops-basics-to-production)
course on devoriales.com, which continues into multi-cluster, RBAC, secrets and a capstone
platform.

Let's write one object and get three Applications.
