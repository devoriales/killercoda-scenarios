# Hooks: work that happens around a sync

Step 1 gated a Deployment on a migration Job using a wave. That works, and it leaves you with
a Job sitting in the namespace forever, counted as part of the application, re-applied on
every sync and never re-run.

Hooks are the other answer. Same idea, different thing entirely.

```
argocd.argoproj.io/hook: PreSync
```

That one annotation changes what the resource **is**.

| Phase | Runs | Use it for |
| --- | --- | --- |
| `PreSync` | before any resource is applied | migrations, draining connections, backups |
| `Sync` | alongside the normal resources | rarely, ordering within a sync is what waves are for |
| `PostSync` | after everything is applied **and Healthy** | smoke tests, cache warming, notifications |

`PostSync` waiting for Healthy rather than merely applied is what makes it the right place for
a smoke test. A `Sync` phase hook would run while the Deployment was still rolling out,
against nothing.

## Watch the phases

`kubectl apply -f /root/manifests/02-hooks/hooks-application.yaml`{{exec}}

`argocd app sync hooks`{{exec}}

Two columns in that output are doing the teaching:

```
GROUP  KIND        NAMESPACE  NAME            STATUS     HEALTH   HOOK      MESSAGE
batch  Job         demo       hooks-presync   Succeeded  Synced   PreSync   Reached expected number of succeeded pods
apps   Deployment  demo       hooks-app       Synced     Healthy            deployment.apps/hooks-app created
batch  Job         demo       hooks-postsync  Succeeded  Synced   PostSync  Reached expected number of succeeded pods
```

**The `HOOK` column** names the phase, and is empty for the Deployment. That empty cell is how
you tell desired state from a task at a glance.

**The `STATUS` column** reads `Succeeded` for the hooks and `Synced` for the Deployment.
Different words because they answer different questions: did this task run, versus does this
resource match Git.

## A hook is a task, not desired state

This is the difference that matters. Look at how Argo CD lists them:

`kubectl get application hooks -n argocd -o json | python3 -c "import json,sys; [print({k:v for k,v in r.items() if k in ('kind','name','status','hook','requiresPruning')}) for r in json.load(sys.stdin)['status']['resources']]"`{{exec}}

```
{'kind': 'Deployment', 'name': 'hooks-app', 'status': 'Synced'}
{'hook': True, 'kind': 'Job', 'name': 'hooks-presync', 'requiresPruning': True}
```

The Deployment carries a **sync status**, because it is desired state Argo CD must maintain.
The hook carries `hook: true`, `requiresPruning: true`, and **no sync status at all**.

Now test what that means. Delete a completed hook:

`kubectl delete job hooks-postsync -n demo`{{exec}}

`argocd app get hooks --refresh`{{exec}}

```
Sync Status:        Synced
```

**Still Synced.** Delete a resource Argo CD manages and it goes `OutOfSync` immediately.
Delete a completed hook and nothing happens, because the hook was never a promise about what
the cluster should contain.

## Wave or hook?

The rule of thumb: **if the cluster should contain it, use a wave. If it is work that happens
during a deploy, use a hook.** A migration is work. A ConfigMap is a thing.

Hooks also carry waves, and this surprises people: `sync-wave` on a hook orders it *within its
phase*. Two `PreSync` hooks with waves 0 and 1 run in that order, both still before anything
else.

<details><summary>What happens if a PreSync hook fails?</summary>

The sync aborts and **nothing is applied**. That is the correct behaviour and the whole reason
to put a migration in `PreSync` rather than discovering afterwards that the app is running
against the wrong schema.
</details>
