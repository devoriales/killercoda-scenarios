# AppProject: drawing a boundary

Your Application said `project: default`. Look at what that permits:

`kubectl get appproject default -n argocd -o jsonpath='sourceRepos={.spec.sourceRepos}  destinations={.spec.destinations}'`{{exec}}

```
sourceRepos=["*"]  destinations=[{"namespace":"*","server":"*"}]
```

**Any repository, into any namespace, on any cluster.** On a learning cluster that is fine.
On a shared one it means anyone who can create an Application can deploy anything, from
anywhere, into any namespace Argo CD can reach, `kube-system` included.

An `AppProject` narrows that. Read one:

`cat /root/manifests/02-appproject/restricted-project.yaml`{{exec}}

Four boundaries, each answering a different question:

| Field | Question it answers |
| --- | --- |
| `sourceRepos` | Where may manifests come from? |
| `destinations` | Which cluster and namespace may they go to? |
| `clusterResourceWhitelist` | Which cluster-scoped kinds may be created? |
| `namespaceResourceWhitelist` | Which namespaced kinds may be created? |

`clusterResourceWhitelist: []` is the one worth memorising. An empty list is not "no
restriction", it is **nothing cluster-scoped at all**: no ClusterRole, no
ClusterRoleBinding, no CRD, no Namespace. That single line is what stops a tenant granting
itself cluster-admin through a manifest.

## Watch it reject something

Create the project:

`kubectl apply -f /root/manifests/02-appproject/restricted-project.yaml`{{exec}}

Now apply an Application that points at a repository the project does not allow. There is
nothing wrong with the repo itself; it is simply not on the list:

`kubectl apply -f /root/manifests/02-appproject/forbidden-app.yaml`{{exec}}

```
application.argoproj.io/forbidden created
```

**Created.** Kubernetes accepted it, because the object is valid. Wait a few seconds, then
ask Argo CD what it thinks:

`kubectl get application forbidden -n argocd -o jsonpath='{.status.conditions[*].message}'`{{exec}}

```
application repo https://github.com/argoproj/argocd-example-apps.git is not permitted in project 'course'
```

Two things worth taking away.

**The rejection is a condition on the resource, not an error from `kubectl apply`.** A
pipeline that only checks whether the apply succeeded will report this deployment as a
success. It is not.

**The message names the exact boundary that was crossed**: which field, which value, which
project. When an Application refuses to sync and you do not know why, read
`.status.conditions` before anything else.

## The shape this takes in a real cluster

One project per team or per environment:

- `platform`: the platform team's repo, allowed to create cluster-scoped resources
- `team-a`: team A's repo, namespaces `team-a-*`, nothing cluster-scoped
- `team-b`: the same, scoped to its own namespaces

"Can team A deploy into team B's namespace?" now has a configuration answer instead of a
social one, and that answer is a file in Git.

<details><summary>Conditions came back empty?</summary>

The controller may not have evaluated it yet. Wait five seconds and run the command again,
or force it:

`argocd app get forbidden --hard-refresh`{{copy}}
</details>
