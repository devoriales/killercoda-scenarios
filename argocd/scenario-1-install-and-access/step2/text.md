# Prove the install is actually healthy

The manifest applied. That means the objects exist, not that anything is running.

## Wait for the workloads

`kubectl wait --for=condition=Available --timeout=300s deployment --all -n argocd`{{exec}}

`kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s`{{exec}}

Six deployments report `condition met` and the StatefulSet rolls out.

## Why that is not proof

**A Deployment reports `Available` as soon as one replica is up.** If the node is under
memory or disk pressure and killing replicas in a loop, one survivor is enough for
`kubectl wait` to return success over the top of a broken install.

So check the pods themselves, and the node conditions that would cause the churn:

`kubectl get pods -n argocd`{{exec}}

You want seven pods, all `Running`, all `1/1`. Anything `Evicted`, `Pending`, or with a
climbing `RESTARTS` count is worth understanding before you build on it.

`kubectl get nodes -o custom-columns='NAME:.metadata.name,DISK:.status.conditions[?(@.type=="DiskPressure")].status,MEM:.status.conditions[?(@.type=="MemoryPressure")].status'`{{exec}}

Both should read `False`. If `DiskPressure` is `True`, the kubelet is evicting pods and
the fix is disk space, not reinstalling Argo CD.

## What seven workloads you got

`kubectl get deploy,statefulset -n argocd`{{exec}}

```
argocd-applicationset-controller
argocd-dex-server
argocd-notifications-controller
argocd-redis
argocd-repo-server
argocd-server
argocd-application-controller   (StatefulSet)
```

Worth noticing now:

- **`argocd-application-controller` is a StatefulSet**, everything else is a Deployment.
  It shards work by identity when scaled, so its pods need stable names.
- **`argocd-dex-server` is running and completely unconfigured.** Dex brokers SSO, and
  there is no SSO configured, so it sits idle. Check for yourself:

`kubectl get cm argocd-cm -n argocd -o jsonpath='{.data.dex\.config}'`{{exec}}

Empty. Dex only starts doing anything once you add a `dex.config` key.

- **`argocd-notifications-controller`** is in the same position: running, no triggers
  defined, nothing to do.

Two of your seven workloads exist for features you are not using. That is exactly what
Argo CD Core omits.

## Confirm the version

Never trust the URL you typed. Ask the cluster what is actually running:

`kubectl get deploy argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'`{{exec}}

```
quay.io/argoproj/argocd:v3.4.5
```

That is the number to quote in a bug report.
