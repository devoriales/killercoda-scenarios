# Letting a tenant own their Applications

Every Application so far lived in the `argocd` namespace. That is the default, and it means
**creating an Application requires write access to `argocd`**, the same namespace holding
cluster credentials, repository secrets and the RBAC policy you just wrote.

For a platform team serving several product teams that is the whole problem in one sentence.
You either grant tenants access to your most sensitive namespace, or you become a ticket queue
for Application manifests.

Two questions people conflate, worth separating first:

| Question | Setting |
| --- | --- |
| Which namespaces may **contain Applications**? | `application.namespaces` |
| Which namespaces may Argo CD **deploy into**? | `AppProject.spec.destinations` |

Step 1 was the second one. This is the first.

## The default is silence

The tenant already has a namespace. Put an Application in it:

`cat /root/manifests/03-namespaces/tenant-app.yaml`{{exec}}

`kubectl apply -f /root/manifests/03-namespaces/tenant-app.yaml`{{exec}}

`sleep 15 && kubectl get application tenant-owned -n tenant-a -o jsonpath='sync=[{.status.sync.status}] health=[{.status.health.status}] conditions=[{.status.conditions[*].message}]{"\n"}'`{{exec}}

```
sync=[] health=[] conditions=[]
```

**Nothing. No status, no conditions, no events.** Kubernetes stored the object because it is
valid, and the controller never looked at it, because it does not watch that namespace.

This is the worst possible failure shape for a beginner: everything reports success and nothing
happens. If a tenant tells you their Application "does nothing at all", check which namespace
it is in before anything else.

## Gate one: let the controller see the namespace

`kubectl patch cm argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"application.namespaces":"tenant-*"}}'`{{exec}}

`kubectl rollout restart statefulset/argocd-application-controller deployment/argocd-server -n argocd`{{exec}}

`kubectl rollout status statefulset argocd-application-controller -n argocd --timeout=200s`{{exec}}

A glob, or a comma-separated list. Now look again:

`sleep 20 && kubectl get application tenant-owned -n tenant-a -o jsonpath='sync=[{.status.sync.status}] conditions=[{.status.conditions[*].message}]{"\n"}'`{{exec}}

```
sync=[Unknown] conditions=[application 'tenant-owned' in namespace 'tenant-a' is not permitted to use project 'tenant-a']
```

Still not working, and **this is progress**: silence became a specific, actionable rejection.

## Gate two: let the project accept the namespace

The project must say which namespaces may declare Applications belonging to it:

`kubectl patch appproject tenant-a -n argocd --type merge -p '{"spec":{"sourceNamespaces":["tenant-a"]}}'`{{exec}}

`sleep 20 && kubectl get application tenant-owned -n tenant-a -o jsonpath='sync=[{.status.sync.status}] conditions=[{.status.conditions[*].message}]{"\n"}'`{{exec}}

```
sync=[Unknown] conditions=[application 'tenant-owned' in namespace 'tenant-a' is not permitted to use project 'tenant-a']
```

**The same rejection, and the patch was correct.** Confirm the project really did change:

`kubectl get appproject tenant-a -n argocd -o jsonpath='{.spec.sourceNamespaces}{"\n"}'`{{exec}}

```
["tenant-a"]
```

Editing an AppProject does not re-queue the Applications that reference it. The condition
you are reading was written on the last reconciliation, which happened **before** the patch,
and nothing has recomputed it since. Argo CD will get there on its own at the next poll,
which is `timeout.reconciliation`, three minutes by default.

Rather than wait, ask for it:

`kubectl annotate application tenant-owned -n tenant-a argocd.argoproj.io/refresh=hard --overwrite`{{exec}}

`sleep 25 && kubectl get application tenant-owned -n tenant-a -o jsonpath='sync=[{.status.sync.status}] health=[{.status.health.status}] conditions=[{.status.conditions[*].message}]{"\n"}'`{{exec}}

```
sync=[OutOfSync] health=[Missing] conditions=[]
```

**No conditions, and a real sync status.** `OutOfSync` and `Missing` are correct here: the
Application is being evaluated properly and its resources have not been created yet, because
nothing has synced it.

This staleness is worth remembering beyond this lab. **Whenever you change an AppProject and
the Applications under it do not react, you are usually looking at a cached condition rather
than a failed change.** Check the project's spec first, then refresh, and only then start
doubting the change itself. Three minutes of a stale error message is long enough for most
people to conclude the fix did not work and go change something else.

And it is visible from the control plane:

`kubectl get applications -A | grep -E 'NAMESPACE|tenant'`{{exec}}

```
NAMESPACE   NAME                 SYNC STATUS   HEALTH STATUS
argocd      tenant-a-web         OutOfSync     Missing
tenant-a    tenant-owned         OutOfSync     Missing
```

Two Applications in two namespaces, both governed by the same project. The tenant owns the
one in their namespace; you never gave them access to yours.

## Why two gates rather than one

The split is the design, not bureaucracy.

**The platform team opens the door** with `application.namespaces`, a cluster-wide setting only
they can change. **The project decides who walks through it** with `sourceNamespaces`, per
tenant.

A tenant cannot grant themselves access by creating an AppProject, because projects live in
`argocd`. And the platform team does not have to enumerate every tenant in a restart-requiring
ConfigMap, because a glob covers the pattern while projects handle the specifics.

Note that the AppProject itself stays in `argocd`. Tenants get their own namespace for
Applications, **not** authority over the boundaries applied to them.

## What this does not give you

A namespace is not a security boundary on its own. A tenant who can create Applications in
their namespace can still target any destination their project allows. `application.namespaces`
decides **where the Application object lives**; what it may deploy is still step 1's work.

<details><summary>A tenant Application still doing nothing?</summary>

Check the glob actually matches. `tenant_b` does not match `tenant-*`, and there is no warning:

`kubectl get cm argocd-cmd-params-cm -n argocd -o jsonpath='{.data.application\.namespaces}'`{{copy}}

And remember both the controller and the server read this at startup, so the setting does
nothing until they restart.
</details>
