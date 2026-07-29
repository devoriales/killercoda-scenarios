# Auto-sync and self-heal

Every Application so far has waited for you to run `argocd app sync`. That is the default,
and it is the safest place to start: Argo CD compares constantly and acts never. An app sits
at `OutOfSync` indefinitely, correctly reporting a difference it will not resolve.

That is a legitimate production choice. It gives you a drift alarm without handing over
write authority.

This step removes the human from the loop.

`cat /root/manifests/04-autosync/autosync-application.yaml`{{exec}}

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Both sub-settings are independent, and **both are off by default even when `automated` is
present**.

## It deploys itself

Apply it and then do nothing at all. No sync command:

`kubectl apply -f /root/manifests/04-autosync/autosync-application.yaml`{{exec}}

`sleep 45 && kubectl get application autosync -n argocd`{{exec}}

```
NAME       SYNC STATUS   HEALTH STATUS
autosync   Synced        Healthy
```

From here on, a commit to the repo becomes a change in the cluster with no command in
between.

## Watch self-heal work

This is the setting that makes GitOps mean something.

Git says one replica:

`kubectl get deploy autosync -n demo -o jsonpath='{.spec.replicas}'`{{exec}}

Now make the classic 3 a.m. change, straight into the cluster:

`kubectl scale deploy autosync -n demo --replicas=5`{{exec}}

`kubectl get deploy autosync -n demo -o jsonpath='{.spec.replicas}'`{{exec}}

Five. Now wait, and watch without touching anything:

`for i in $(seq 1 8); do echo "$(date +%T) replicas=$(kubectl get deploy autosync -n demo -o jsonpath='{.spec.replicas}')"; sleep 5; done`{{exec}}

```
12:31:02 replicas=5
12:31:07 replicas=5
12:31:12 replicas=1
12:31:17 replicas=1
```

**Seconds, and no human involved.** Git said one, the cluster said five, and Argo CD
resolved the disagreement in Git's favour. Expect somewhere around five to fifteen seconds
rather than a fixed number, depending on how quickly the controller notices.

Without `selfHeal`, Argo CD would have shown `OutOfSync` and left your five replicas
running.

## The sharp edge

During an incident, **scaling up by hand no longer works**. You will scale, feel relief, and
watch it revert. The fix is a commit, and that is a process change rather than a tooling
one. Teams usually discover this at the worst possible moment.

The same applies to CI. Auto-sync plus a pipeline that also deploys means CI pushes an image
tag, Argo CD reverts it within seconds, CI runs again. Neither reports an error. **If you
turn on `selfHeal`, CI must stop writing to the cluster.** There is no configuration that
lets both win.

## `prune`, and why it is last

Without `prune`, deleting a manifest from Git leaves the resource running forever. With
`prune: true`, removing a file removes the resource.

Be deliberate with it on anything stateful: a PersistentVolumeClaim removed from Git is a
PersistentVolumeClaim deleted from the cluster. Protect what must survive a mistake:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
```

## Choosing

| Setting | Argo CD will | Use when |
| --- | --- | --- |
| nothing | report drift, change nothing | a human approves every rollout |
| `automated` | apply commits from Git | you trust the repo and its review process |
| `+ selfHeal` | revert manual cluster changes | the cluster must match Git, always |
| `+ prune` | delete what Git no longer declares | your repo is genuinely the full picture |

Start manual, add `automated` once you trust the pipeline, add `selfHeal` once the team has
stopped using `kubectl edit` as a fix, and add `prune` last. Reversing that order on a repo
nobody reviews is how Argo CD gets a reputation for deleting things.
