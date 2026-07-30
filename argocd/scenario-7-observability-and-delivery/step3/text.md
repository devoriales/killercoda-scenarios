# The metric worth being woken up for

Notifications tell you when something changed. Metrics tell you what is true right now, and
they are the half that still works when Argo CD itself is the problem: a scrape target that
stops responding **generates** an alert, while a notification that never fires looks exactly
like a quiet day.

The application controller exposes metrics on its own Service:

`kubectl get svc -n argocd | grep metrics`{{exec}}

```
argocd-metrics                            ClusterIP   10.96.x.x    <none>   8082/TCP
argocd-notifications-controller-metrics   ClusterIP   10.96.x.x    <none>   9001/TCP
argocd-server-metrics                     ClusterIP   10.96.x.x    <none>   8083/TCP
```

Three endpoints, and **the one you want is `argocd-metrics`** on 8082. Scraping only
`argocd-server-metrics` because it sounds like the main one is a common mistake: application
health and sync state are not there.

`kubectl port-forward -n argocd svc/argocd-metrics 8082:8082 > /dev/null 2>&1 &`{{exec}}

`sleep 4 && curl -s localhost:8082/metrics | grep '^argocd_app_info' | head -2`{{exec}}

```
argocd_app_info{autosync_enabled="false",dest_namespace="contested",dest_server="https://kubernetes.default.svc",health_status="Healthy",name="owner-a",namespace="argocd",operation="",project="default",repo="https://github.com/devoriales/argocd-beginner",sync_status="Synced"} 1
```

**Read the labels, because the labels are the whole API.** `health_status`, `sync_status`,
`project`, `dest_server`, `repo`, and the one most people miss: `autosync_enabled`.

## Now create the drift that matters

The 3 a.m. change, made by a human in a hurry:

`kubectl scale deploy web-dev -n contested --replicas=5`{{exec}}

`sleep 20 && kubectl get application owner-a -n argocd`{{exec}}

```
NAME      SYNC STATUS   HEALTH STATUS
owner-a   OutOfSync     Healthy
```

Nothing is broken. Five replicas are running happily. **Git says one, and nothing will ever
correct it,** because this Application has no automated sync.

`curl -s localhost:8082/metrics | grep '^argocd_app_info' | grep 'sync_status="OutOfSync"' | grep 'autosync_enabled="false"'`{{exec}}

```
argocd_app_info{autosync_enabled="false",...,name="owner-a",...,sync_status="OutOfSync"} 1
```

As a Prometheus rule that is:

```promql
sum by (name) (argocd_app_info{sync_status="OutOfSync", autosync_enabled="false"})
```

**Both label filters matter.** On a cluster with automated sync, applications pass through
`OutOfSync` constantly and briefly, so alerting on `sync_status="OutOfSync"` alone pages you all
night and trains everyone to ignore it. Adding `autosync_enabled="false"` narrows it to the case
that cannot self-correct: **a human changed production and Git does not know.** That is also the
compliance-relevant signal from Module 8, because it is drift with no audit trail.

If you do want to alert on all drift, put a `for: 15m` on the rule so transient states never fire.

## The queue metrics, and the name that does not exist

Saturation shows up as queue depth. The names are not what you would guess:

`curl -s localhost:8082/metrics | grep '^workqueue_depth'`{{exec}}

```
workqueue_depth{controller="app_hydration_queue",name="app_hydration_queue",priority=""} 0
workqueue_depth{controller="app_operation_processing_queue",name="app_operation_processing_queue",priority=""} 0
workqueue_depth{controller="app_reconciliation_queue",name="app_reconciliation_queue",priority=""} 0
workqueue_depth{controller="manifest_hydration_queue",name="manifest_hydration_queue",priority=""} 0
workqueue_depth{controller="project_reconciliation_queue",name="project_reconciliation_queue",priority=""} 0
```

Five queues, exposed through the shared Kubernetes `workqueue` metrics rather than under an
`argocd_` prefix. Two of them belong to the Source Hydrator and exist whether or not you have
enabled it.

Prove the obvious guess is wrong:

`curl -s localhost:8082/metrics | grep -c '^argocd_app_reconciliation_queue'`{{exec}}

```
0
```

**A PromQL query against a metric that does not exist returns no data, and no data looks
exactly like a healthy queue.** This is the single most useful reason to curl the endpoint once
before writing any alert: confirm the metric name exists in the build you are actually running.

What you want from these is the **shape**, not the number. A queue that rises and falls to zero
is healthy. A queue pinned at its ceiling and never draining is a controller that never catches
up, which is Module 10's tuning lesson.

## The four alerts worth having

| Alert | Query |
| --- | --- |
| Something is broken | `argocd_app_info{health_status="Degraded"}` |
| Uncorrected drift | `argocd_app_info{sync_status="OutOfSync", autosync_enabled="false"}` |
| A cluster is unreachable | `argocd_cluster_connection_status == 0` |
| Argo CD cannot keep up | `workqueue_depth{name="app_reconciliation_queue"}` sustained high |

Now put Git back in charge:

`argocd app sync owner-a`{{exec}}

`sleep 10 && kubectl get deploy web-dev -n contested`{{exec}}

Back to one replica, and the alert clears itself.
