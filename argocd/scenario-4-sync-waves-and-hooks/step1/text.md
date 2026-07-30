# Sync waves: making Argo CD wait

Argo CD's built-in kind ordering puts namespaces before workloads and CRDs before most
things. What it cannot do is **wait for something to become ready** before continuing, and
it has no opinion about one workload versus another.

A sync wave adds exactly that:

```
argocd.argoproj.io/sync-wave: "1"
```

A signed integer as a string. Lower runs first, anything unannotated is wave `0`, and
**Argo CD waits for every resource in a wave to report Healthy before starting the next.**

## Three resources that must go in order

The repository holds three resources in one directory:

| Wave | Resource | Why it is there |
| --- | --- | --- |
| 0 | Job `waves-migrate` | stands in for a schema migration, sleeps 15 seconds |
| 1 | Deployment `waves-app` | must not start against an unmigrated database |
| 2 | Job `waves-smoketest` | pointless until the app is actually serving |

These are plain resources, not hooks. **A Job is Healthy only once it has Completed**, which
is what makes it a useful gate.

Read the Application, and note that nothing in it mentions ordering. The waves live on the
resources, so the ordering travels with the manifests:

`cat /root/manifests/01-waves/waves-application.yaml`{{exec}}

Apply it and sync:

`kubectl apply -f /root/manifests/01-waves/waves-application.yaml`{{exec}}

`argocd app sync waves`{{exec}}

Look at the duration in the output:

```
Phase:              Succeeded
Duration:           23s
```

**Twenty three seconds for three tiny resources.** Without waves all three would be applied
in about a second, and the app would come up alongside a migration that had not run.

## Prove it, rather than trusting the duration

A duration is suggestive. Timestamps are evidence:

`kubectl get job/waves-migrate deploy/waves-app job/waves-smoketest -n demo -o custom-columns='KIND:.kind,NAME:.metadata.name,CREATED:.metadata.creationTimestamp'`{{exec}}

```
Job          waves-migrate     ...T11:35:38Z
Deployment   waves-app         ...T11:35:59Z
Job          waves-smoketest   ...T11:36:01Z
```

Now find when the migration actually finished:

`kubectl get jobs -n demo -o custom-columns='NAME:.metadata.name,COMPLETED:.status.completionTime'`{{exec}}

```
waves-migrate     ...T11:35:58Z
```

Line those up. The migration completed at `:58`. The Deployment was created at `:59`, **one
second later.** Argo CD was not applying on a timer, it was waiting for a health status and
moved the instant it changed.

## Choosing wave numbers in real life

Leave gaps, and use negatives for prerequisites:

```
wave -3   Namespace, ResourceQuota, NetworkPolicy
wave -2   CRDs
wave -1   operators and controllers
wave  0   your application (needs no annotation)
wave  1   smoke tests, ServiceMonitors
```

Negatives mean your application resources stay at the default `0` and never need an
annotation at all, which is far easier to maintain than renumbering everything upward when
you insert a step.

<details><summary>Sync seems stuck?</summary>

A wave that never becomes Healthy blocks every wave behind it, with no error, because
nothing has failed. Find the wave that has not completed:

`kubectl get jobs -n demo`{{copy}}
</details>
