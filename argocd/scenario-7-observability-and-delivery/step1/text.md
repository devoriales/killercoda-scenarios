# The diff that looks like nothing

`OutOfSync` says something differs. It does not say what, why, or whether you should care.
The hardest version of that is when the difference is real, permanent, and looks like noise.

Two Applications, same repository, same path, same destination namespace:

`cat /root/manifests/01-ownership/owner-a.yaml`{{exec}}

`kubectl apply -f /root/manifests/01-ownership/owner-a.yaml -f /root/manifests/01-ownership/owner-b.yaml`{{exec}}

**Both accepted.** Nothing in Argo CD stops you declaring two owners for one Deployment.

## Sync one, then the other

`argocd app sync owner-a`{{exec}}

```
GROUP  KIND        NAMESPACE  NAME       STATUS   HEALTH       HOOK  MESSAGE
apps   Deployment  contested  web-dev    Synced   Progressing        deployment.apps/web-dev created
```

`argocd app sync owner-b`{{exec}}

```
apps   Deployment  contested  web-dev  Synced  Healthy        deployment.apps/web-dev configured
```

Note `configured`, not `created`. The second sync did not make a second Deployment: it took
the existing one over.

`sleep 10 && kubectl get application owner-a owner-b -n argocd`{{exec}}

```
NAME      SYNC STATUS   HEALTH STATUS
owner-a   OutOfSync     Healthy
owner-b   Synced        Healthy
```

**`owner-a` is now `OutOfSync` and nothing in Git changed.** It is also `Healthy`, because the
Deployment it wanted does exist and is running.

## The diff, which is the confusing part

`argocd app diff owner-a`{{exec}}

```
===== apps/Deployment contested/web-dev ======
5c5
<     argocd.argoproj.io/tracking-id: owner-b:apps/Deployment:contested/web-dev
---
>     argocd.argoproj.io/tracking-id: owner-a:apps/Deployment:contested/web-dev
```

**One hunk, and it is Argo CD's own bookkeeping annotation.** No replica count, no image, nothing
you wrote. It reads like noise, and it is the entire diagnosis: the live resource says it belongs
to `owner-b`, and `owner-a` wants it to say `owner-a`. Sync either one and it flips.

Worth knowing for pipelines: `argocd app diff` exits non-zero when there are differences, so it
works as a gate. Check it here:

`argocd app diff owner-a >/dev/null; echo "exit=$?"`{{exec}}

```
exit=1
```

## The signal to actually trust

Argo CD says it outright, in a place people rarely look:

`kubectl get application owner-a -n argocd -o jsonpath='{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}'`{{exec}}

```
SharedResourceWarning: Deployment/web-dev is part of applications argocd/owner-a and owner-b
```

Now check the winner:

`kubectl get application owner-b -n argocd -o jsonpath='conditions=[{range .status.conditions[*]}{.type}{end}]{"\n"}'`{{exec}}

```
conditions=[]
```

**Only the app that lost the resource reports the problem.** `owner-b` is `Synced`, `Healthy`,
and silent. An alert on health alone sees nothing wrong with either application.

Confirm ownership directly if you want the one-line version:

`kubectl get deploy web-dev -n contested -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}{"\n"}'`{{exec}}

## A triage order that saves an hour

When something is `OutOfSync` and you do not know why:

| What the diff shows | What it is |
| --- | --- |
| Only a tracking-id | **Ownership conflict.** Two Applications overlap. |
| A field a controller owns (`replicas` under an HPA) | Fighting writers. Stop declaring it, or `ignoreDifferences`. |
| A value a human would change | Somebody edited the cluster. Decide which side is right. |
| Nothing but a revision | Git moved. Sync it. |

The ownership case is the one that never resolves on its own. The fix is not a sync: narrow one
Application's path, or delete the duplicate.

`kubectl delete application owner-b -n argocd`{{exec}}

Deleting `owner-b` leaves the Deployment in place and hands it back on the next reconciliation,
which is what you want when the duplicate was the mistake.

<details><summary>Why is owner-a Healthy while OutOfSync?</summary>

They answer different questions, as Module 3 covered. `Healthy` asks whether the live resources
are working: the Deployment has its replicas available, so yes. `Synced` asks whether the live
resources match what this Application wants: the tracking annotation does not, so no.

An app can be `Synced` and broken, or `OutOfSync` and perfectly healthy. This is the second one.
</details>
