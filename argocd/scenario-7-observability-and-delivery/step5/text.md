# Bootstrapping the whole platform from one file

Every Application so far you created by hand. That does not scale past a few, and it means the
list of what should exist lives in somebody's shell history rather than in Git.

The app-of-apps pattern fixes that with one Application whose job is to create other
Applications. Here is the entire thing you apply by hand, ever:

`cat /root/manifests/05-bootstrap/root-application.yaml`{{exec}}

It points at a directory with `recurse: true` and deploys into `argocd`, because Applications and
AppProjects live there. That directory holds three files: an `AppProject` and two `Application`s.

`kubectl apply -f /root/manifests/05-bootstrap/root-application.yaml`{{exec}}

`sleep 45 && kubectl get application -n argocd | grep -E 'NAME|platform'`{{exec}}

```
NAME                   SYNC STATUS   HEALTH STATUS
platform-root          Synced        Healthy
platform-web-dev       Synced        Healthy
platform-web-staging   Synced        Healthy
```

`kubectl get ns | grep platform`{{exec}}

`kubectl get deploy -A | grep platform`{{exec}}

**One file produced a project, two Applications, two namespaces and two Deployments.** Adding an
environment is now adding one file to that directory. Nothing is applied by hand again.

## The ordering, which is not optional

`kubectl get appproject platform -n argocd -o jsonpath='{.spec.clusterResourceWhitelist}{"\n"}'`{{exec}}

The Applications in that directory reference `project: platform`. If the project did not exist
first they would be rejected, which is Module 5's first ordering rule applied to the platform's
own resources. The files carry sync waves:

| File | Wave | Why |
| --- | --- | --- |
| `00-platform-project.yaml` | `-1` | the project everything references |
| `10-web-dev.yaml`, `10-web-staging.yaml` | `0` | Applications that need it |

## Why root is a special alert

`kubectl delete application platform-web-dev -n argocd`{{exec}}

`sleep 40 && kubectl get application -n argocd | grep -E 'NAME|platform'`{{exec}}

**It is back.** Root has `selfHeal: true`, so an Application deleted out from under it gets
recreated from Git within a reconciliation. Somebody removing an app by hand does not remove it.

Now invert that. **If root stops reconciling, nothing below it is being kept current, and every
one of those child Applications keeps reporting whatever it last reported.** They do not turn red.
They go stale, which looks identical to fine.

That is why Module 10 argues for alerting on the root Application **by name**, separately from the
generic health alerts:

```promql
argocd_app_info{name="platform-root", health_status!="Healthy"}
```

Your other alerts describe Applications that root is responsible for keeping current. A broken
root can leave all of them looking healthy while none of them reflects Git.

## What this costs

The pattern is not free, and the honest limitation matters:

- **Everything shares root's blast radius.** A bad commit to that directory reaches every
  application at once, because prune and selfHeal are on.
- **A tree is not a hierarchy of permissions.** Every child here runs with the same Argo CD
  credentials. Tenancy still comes from the `AppProject`, which is Module 7 and 8's work.
- **Deleting root deletes everything**, with `prune: true`. That is the intent, and it is a
  genuinely alarming command to run by accident.

<details><summary>A child Application stuck at OutOfSync / Missing with no conditions</summary>

Almost always a project restriction, and it is invisible in the usual places. `status.conditions`
stays empty. The real message is one level deeper:

`kubectl get application platform-web-dev -n argocd -o jsonpath='{range .status.operationState.syncResult.resources[*]}{.kind}/{.name} status={.status} msg={.message}{"\n"}{end}'`{{copy}}

The common cause is Module 8's advice applied too literally. `clusterResourceWhitelist: []` is
right for tenant projects, but a `Namespace` is cluster-scoped, so combining it with
`CreateNamespace=true` gives:

```
Namespace/platform-dev status=SyncFailed msg=resource :Namespace is not permitted in project platform
```

And fixing the project is not enough on its own: the failed sync keeps retrying with backoff and
holds the operation open. Clear it first with `argocd app terminate-op platform-web-dev`, then sync.
</details>
