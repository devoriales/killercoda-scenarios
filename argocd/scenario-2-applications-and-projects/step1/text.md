# Your first Application

An `Application` is a normal Kubernetes object. Read the one you are about to apply:

`cat /root/manifests/01-application/demo-application.yaml`{{exec}}

Five fields do the work:

| Field | What it decides |
| --- | --- |
| `source.repoURL` | which Git repository |
| `source.targetRevision` | which branch, tag or commit |
| `source.path` | which directory inside it |
| `destination.server` | which cluster |
| `destination.namespace` | which namespace |

Note where the Application itself lives: **`metadata.namespace: argocd`**, not `demo`. The
Application is a record of intent held by Argo CD. It is not part of the workload, and
looking for it in the namespace it deploys to returns nothing.

Apply it:

`kubectl apply -f /root/manifests/01-application/demo-application.yaml`{{exec}}

Now look at it:

`kubectl get application demo -n argocd`{{exec}}

```
NAME   SYNC STATUS   HEALTH STATUS
demo   OutOfSync     Missing
```

**Nothing has been deployed.** `OutOfSync` means the cluster does not match Git, and
`Missing` means the resources do not exist. Argo CD noticed the difference and did nothing
about it, because this Application has no automated sync policy. That is the default, and
it is the safe one.

## Sync it

`argocd app sync demo`{{exec}}

Watch the order in the output:

```
GROUP  KIND        NAMESPACE  NAME  STATUS   HEALTH       HOOK  MESSAGE
       Namespace              demo  Running  Synced             namespace/demo created
       Service     demo       demo  Synced   Healthy            service/demo created
apps   Deployment  demo       demo  Synced   Progressing        deployment.apps/demo created
```

The Namespace was created first, without being asked. Argo CD applies resources in a
built-in kind order: namespaces, then CRDs, then RBAC, then config, then workloads. You did
not specify that ordering and cannot get it wrong.

The Service is `Healthy` immediately while the Deployment is only `Progressing`. A Service
has almost nothing to wait for; a Deployment has pods to schedule.

Give it a few seconds, then:

`kubectl get application demo -n argocd`{{exec}}

`kubectl get all -n demo`{{exec}}

Two manifests were in that directory. Everything else you can see, the ReplicaSet and the
pods, was created by Kubernetes rather than by Argo CD.

## Who owns this resource?

Argo CD writes an annotation onto everything it applies:

`kubectl get deploy demo -n demo -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'`{{exec}}

```
demo:apps/Deployment:demo/demo
```

That reads as *Application `demo` owns the `apps/Deployment` called `demo` in namespace
`demo`*. It is how Argo CD knows which resources belong to which Application, and it is the
first thing to check when an app behaves strangely. You will use it in step 4.

<details><summary>Nothing appeared after the sync?</summary>

Check the Application's conditions:

`kubectl get application demo -n argocd -o jsonpath='{.status.conditions[*].message}'`{{copy}}

If sync status reads `Unknown`, the controller could not build its cluster cache yet.
Force it: `argocd app get demo --hard-refresh`
</details>
