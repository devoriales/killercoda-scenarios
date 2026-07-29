# A directory of plain YAML

Start with the simplest case, because the other three are variations on it.

`cat /root/manifests/01-plain/plain-application.yaml`{{exec}}

Nothing in that file says "this is plain YAML". Argo CD reads the directory, finds no
`kustomization.yaml` and no `Chart.yaml`, and applies what is there.

**The directory is the unit, not a file list.** There is no `files:` field. Adding a
manifest to that folder in Git is enough to have it deployed on the next sync, which is
convenient and occasionally surprising: a stray `notes.yaml` containing valid Kubernetes
YAML gets applied too.

Deploy it:

`kubectl apply -f /root/manifests/01-plain/plain-application.yaml`{{exec}}

`argocd app sync plain`{{exec}}

## Argo CD works out the order

Look at what the sync did:

```
GROUP  KIND        NAMESPACE  NAME  STATUS   HEALTH       HOOK  MESSAGE
       Namespace              demo  Running  Synced             namespace/demo created
       Service     demo       demo  Synced   Healthy            service/demo created
apps   Deployment  demo       demo  Synced   Progressing        deployment.apps/demo created
```

Namespace first, without being asked. Argo CD applies resources in a **built-in kind
order**: namespaces, then CustomResourceDefinitions, then ServiceAccounts and RBAC, then
ConfigMaps and Secrets, then workloads, then networking.

Apply a Deployment before its Namespace by hand and it fails. Here you cannot get it wrong.
When that default is not enough, sync waves let you impose your own ordering.

Two manifests were in the directory. See what exists now:

`kubectl get all -n demo`{{exec}}

The ReplicaSet and the pods were created by Kubernetes, not by Argo CD. Argo CD tracks what
it applied and follows ownership downwards from there.

## Seeing a change before you apply it

This is the command worth remembering:

`argocd app diff plain`{{exec}}

It renders the manifests from Git, diffs them against live state, and prints only the
differences. It is the closest thing Argo CD has to a plan step, and it exits quietly when
there is nothing to report, which is what you should see now.

An **empty diff on an app that reports `OutOfSync`** is a real situation and it usually
means something else took ownership of the resources. Check the tracking-id when that
happens.

## Recursion is off by default

Subdirectories are ignored unless you ask:

```yaml
source:
  directory:
    recurse: true
```

Turning it on for a repo that also contains, say, a `kustomize/` folder means those files
get applied as plain YAML as well, which is rarely what anyone wants. Prefer one directory
per Application over recursion.

<details><summary>Sync reports Unknown?</summary>

The controller may still be building its cluster cache on a freshly installed Argo CD.
Force the comparison:

`argocd app get plain --hard-refresh`{{copy}}
</details>
