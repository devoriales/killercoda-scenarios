# Applications, projects, and the two statuses that matter

Installing Argo CD gives you a controller with nothing to do. It sits there comparing an
empty list of things against an empty cluster.

An **Application** is what gives it work. One Kubernetes object that says where the desired
state lives and where it should end up. Everything Argo CD does follows from those two
answers, and almost every confusing thing about Argo CD makes sense once you can read one.

In the next 25 minutes you will:

- Create an Application and watch Argo CD build a namespace, a Service and a Deployment from a directory in Git
- Find out who owns a resource, and why two Applications must never claim the same one
- Lock an Application down with an **AppProject**, then watch a project reject one
- Produce an app that is **Synced and broken at the same time**, which is the single most
  useful thing to understand about Argo CD's two status columns
- Build an **app-of-apps**: one Application whose job is creating other Applications

## What is already set up

Argo CD 3.4.5 is installed and running in the `argocd` namespace, and the `argocd` CLI is
ready to use. Installing it is [scenario 1](https://killercoda.com/devoriales/course/argocd/scenario-1-install-and-access),
including the part where the obvious install command quietly half-fails.

The CLI is in **core mode**, which talks to the Kubernetes API directly rather than to
`argocd-server`. That means no port-forward to keep alive and no password to paste. Every
command works exactly as it would against the API server.

All the manifests you need are in `/root/manifests/`, and the Git repository they point at
is [devoriales/argocd-beginner](https://github.com/devoriales/argocd-beginner), the same
public repo the full course uses.

## Part of a course

This scenario covers Module 3 of the free
[The Complete Argo CD Course](https://devoriales.com/quiz/26/the-complete-argo-cd-course-gitops-basics-to-production) course on devoriales.com, which
goes deeper on each idea here and continues into Kustomize, Helm, ApplicationSets, RBAC
and multi-cluster.

Let's build something for Argo CD to reconcile.
