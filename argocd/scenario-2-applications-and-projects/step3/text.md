# Synced and broken at the same time

Every Application shows two statuses, and reading them as one thing is the most common
beginner mistake. They answer different questions:

| Status | Question | Compares |
| --- | --- | --- |
| **Sync** | Does the cluster match Git? | live resources against the manifests |
| **Health** | Is the thing actually working? | live resources against what "working" means for their kind |

Deploy something that is perfectly valid and cannot possibly run:

`cat /root/manifests/03-health/broken-application.yaml`{{exec}}

The manifest it points at asks for `nginx:this-tag-does-not-exist`. The YAML is well formed
and the API server will accept it without complaint.

`kubectl apply -f /root/manifests/03-health/broken-application.yaml`{{exec}}

`argocd app sync broken`{{exec}}

The sync **succeeds**. Now watch the health status over the next minute:

`kubectl get applications -n argocd`{{exec}}

```
NAME     SYNC STATUS   HEALTH STATUS
broken   Synced        Progressing
demo     Synced        Healthy
```

`Progressing`, not `Degraded`, at first. Kubernetes gives a rollout time to finish before
declaring it failed, and the default is **600 seconds**. Ten minutes of `Progressing` is
indistinguishable from "slow", which is exactly why a stuck rollout can go unnoticed.

This manifest sets `progressDeadlineSeconds: 60` so you do not have to wait ten minutes.
Give it a minute:

`sleep 60 && kubectl get applications -n argocd`{{exec}}

```
NAME     SYNC STATUS   HEALTH STATUS
broken   Synced        Degraded
demo     Synced        Healthy
```

**Both are Synced. One works and one does not.**

Sync is telling the truth. The cluster genuinely does match Git: the Deployment exists
exactly as written. Git just happens to describe something that cannot run. The reason is
one command away:

`kubectl get pods -n demo -l app=broken`{{exec}}

```
NAME                      READY   STATUS             RESTARTS   AGE
broken-5c4fb55748-wkcsp   0/1     ImagePullBackOff   0          2m
```

## The five health states

| State | Meaning |
| --- | --- |
| `Healthy` | working as intended |
| `Progressing` | not there yet, still within its deadline |
| `Degraded` | failed, or exceeded its deadline |
| `Missing` | declared in Git, absent from the cluster |
| `Unknown` | health could not be determined |

Health is computed per resource kind using rules that match how Kubernetes reports
readiness. A Deployment is healthy when its replicas are available and the rollout is
complete. A Service is healthy immediately unless it is a `LoadBalancer` waiting for an
address. That is why the Service went green before the Deployment in step 1.

## What to take from this

**A green `Synced` tells you nothing about whether your service works.** It tells you the
cluster matches Git. If Git describes a broken thing, Argo CD will faithfully make your
cluster broken and report success, because that is precisely what you asked for.

After a deploy, look at **health**. Sync going green only means the handoff completed.
