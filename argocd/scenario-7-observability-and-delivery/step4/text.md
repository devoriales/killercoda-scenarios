# A canary that stops and waits

Everything so far ended at "the cluster matches Git". A rolling update protects against exactly
one failure, a pod that will not start, and that is not the failure that hurts. A pod can start
perfectly, pass its readiness probe, and return 500 on every request. Kubernetes finishes the
update, Argo CD reports success, and the outage is total.

Argo Rollouts was installed while you worked through the first three steps. Make sure its
controller has finished starting before you rely on it, because a `Rollout` object applied
before the controller is running simply sits there doing nothing:

`kubectl rollout status deploy/argo-rollouts -n argo-rollouts --timeout=300s`{{exec}}

```
deployment "argo-rollouts" successfully rolled out
```

It replaces your `Deployment` with a `Rollout`, and the spec is deliberately almost identical:

```yaml
kind: Rollout          # was: Deployment
spec:
  replicas: 4
  template: ...        # identical to a Deployment podTemplate
  strategy:            # the only genuinely new part
    canary:
      steps:
        - setWeight: 25
        - pause: {}    # empty pause waits for a human
```

**Your Argo CD Application does not change at all.** Same repo, same path, same sync policy.

`kubectl apply -f /root/manifests/04-canary/canary-application.yaml`{{exec}}

`argocd app sync canary-web`{{exec}}

```
GROUP        KIND       NAMESPACE    NAME         STATUS   HEALTH       HOOK  MESSAGE
             Service    canary-demo  web          Synced   Healthy            service/web created
argoproj.io  Rollout    canary-demo  web          Synced   Progressing        rollout.argoproj.io/web created
```

`sleep 20 && kubectl argo rollouts get rollout web -n canary-demo`{{exec}}

The first deploy has **no canary**. There is no previous version to shift traffic away from, so
Argo Rollouts brings up all four replicas at once. Canary steps apply to *changes*.

## Now change the image

In production this is a merged commit bumping a tag. This lab cannot push to the course
repository, so the same change is expressed by pointing the Application at a second path holding
the identical Rollout with a different tag. **The desired state still comes from Git either way.**

`kubectl patch application canary-web -n argocd --type merge -p '{"spec":{"source":{"path":"module-11-progressive-delivery/03-wiring-argocd-with-rollouts/v2"}}}'`{{exec}}

`argocd app sync canary-web`{{exec}}

Watch the two systems from one place:

`for i in $(seq 1 20); do APP=$(kubectl get application canary-web -n argocd -o jsonpath='{.status.health.status}'); RO=$(kubectl get rollout web -n canary-demo -o jsonpath='{.status.phase}|{.status.message}'); echo "app=$APP  rollout=$RO"; [ "${RO%%|*}" = "Paused" ] && break; sleep 8; done`{{exec}}

```
app=Progressing  rollout=Progressing|more replicas need to be updated
app=Progressing  rollout=Progressing|more replicas need to be updated
app=Suspended    rollout=Paused|CanaryPauseStep
```

The loop stops at the first `Paused`, so it costs you only as long as the roll actually takes.
**How many `Progressing` lines you get depends entirely on how fast this VM pulls and starts a
pod**, and on a slow one it can be most of them. What matters is where it lands.

## `Suspended`, and why it is the right answer

Most people guess `Progressing`. That does flash past for a few seconds while replicas roll, and
then the Application settles on **`Suspended`** for as long as the canary is paused. You get
`Suspended` for both kinds of pause: an empty `pause: {}` waiting on a human and a
`pause: {duration: 5m}` waiting on a clock look identical, so the status tells you the rollout is
holding, not why.

What matters is what it is **not**:

| If a paused canary reported | Then |
| --- | --- |
| `Healthy` | a `RollingSync` from Module 6 would promote to the next environment mid-canary |
| `Degraded` | every paused canary would page somebody |
| `Suspended` | neither happens, which is correct |

**One practical consequence: never alert on "not Healthy".** On a cluster running canaries that
fires during every normal deployment. Alert on `Degraded`.

Confirm the traffic split is real:

`kubectl get pods -n canary-demo -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[0].image' --no-headers | sort -k2`{{exec}}

One pod on the new tag, three on the old. That is `setWeight: 25` with four replicas, and the
single Service in front of them splits traffic by pod count.

## Promotion

`kubectl argo rollouts promote web -n canary-demo`{{exec}}

`sleep 25 && kubectl get application canary-web -n argocd`{{exec}}

```
NAME         SYNC STATUS   HEALTH STATUS
canary-web   Synced        Healthy
```

That was an imperative command against the cluster, which sits awkwardly next to everything this
course has said about Git. The honest resolution: **the desired state is still in Git.** The image
tag, the strategy and the steps are all declared. What you promoted is a transition Git already
approved, not a new intent. Argo CD never considered the Rollout `OutOfSync` while it was paused,
because the object always matched.

If you want promotion itself to be auditable, use automated analysis instead of manual pauses and
let a metric decide. Then there is no human action to record.

The canary has served its purpose, and the next step brings up a small platform of its own.
Give the node its four replicas back:

`kubectl delete application canary-web -n argocd && kubectl delete ns canary-demo --wait=false`{{exec}}

Deleting the Application removes the Rollout with it, because Argo CD owns that object. This is
the same ownership you saw in step 1, used deliberately this time.

<details><summary>Who owns what, and the two ways this goes wrong</summary>

**Argo CD owns the object. Argo Rollouts owns the progression. Neither owns the image tag**,
which is in Git.

*`selfHeal` fighting a rollback.* Argo Rollouts rolls back by adjusting the live Rollout. With
`selfHeal: true`, Argo CD can read that as drift and push it forward again. An automatic rollback
is **temporary** until you revert the commit.

*The Service selector, on blue-green.* Argo Rollouts manages the selector to switch traffic. If
Argo CD also manages that Service with `selfHeal`, they fight over it directly. Use
`ignoreDifferences` on `/spec/selector`.
</details>
