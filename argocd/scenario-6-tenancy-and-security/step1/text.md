# The project as a contract

Every Application so far said `project: default`. Look at what that permits:

`kubectl get appproject default -n argocd -o jsonpath='sourceRepos={.spec.sourceRepos}  destinations={.spec.destinations}{"\n"}'`{{exec}}

```
sourceRepos=["*"]  destinations=[{"namespace":"*","server":"*"}]
```

**Any repository, into any namespace, on any cluster.** Fine on a laptop. On a shared cluster
it means anyone who can create an Application can deploy anything, from anywhere, into any
namespace Argo CD can reach, `kube-system` included.

Argo CD holds cluster-admin credentials for every cluster it manages, so this is not a
theoretical concern. The project is what narrows it.

`cat /root/manifests/01-project/tenant-project.yaml`{{exec}}

Read the fields, because each earns its place:

| Field | Stops |
| --- | --- |
| `sourceRepos` | code arriving from an unapproved repository |
| `destinations` | deploying into someone else's namespace, using a glob rather than `*` |
| `clusterResourceWhitelist: []` | **nothing cluster-scoped at all** |
| `namespaceResourceBlacklist` | a tenant raising the quota imposed on them |

`clusterResourceWhitelist: []` deserves emphasis. An empty list is not "no restriction", it is
**nothing cluster-scoped**: no ClusterRole, no ClusterRoleBinding, no CRD, no Namespace.
Without it a tenant can commit a ClusterRoleBinding granting themselves cluster-admin, and
Argo CD will apply it, because Argo CD has the rights to and nothing told it not to.

Create the project:

`kubectl apply -f /root/manifests/01-project/tenant-project.yaml`{{exec}}

## Now try to cross it, twice

First, the right project but a repository that is not on its list:

`kubectl apply -f /root/manifests/01-project/rejected-repo.yaml`{{exec}}

```
application.argoproj.io/rejected-repo created
```

**Created.** Note that carefully. Now the second one, with the approved repo but a destination
of `kube-system`:

`kubectl apply -f /root/manifests/01-project/rejected-namespace.yaml`{{exec}}

Also created. Wait a few seconds, then ask Argo CD what it thinks of each:

`sleep 15 && kubectl get application rejected-repo -n argocd -o jsonpath='{.status.conditions[*].message}{"\n"}'`{{exec}}

```
application repo https://github.com/argoproj/argocd-example-apps.git is not permitted in project 'tenant-a'
```

`kubectl get application rejected-namespace -n argocd -o jsonpath='{.status.conditions[*].message}{"\n"}'`{{exec}}

```
application destination server 'https://kubernetes.default.svc' and namespace 'kube-system' do not match any of the allowed destinations in project 'tenant-a'
```

Two refusals, two different reasons, each naming **the exact boundary crossed**.

## The detail that catches pipelines

Both Applications were **created successfully**. Kubernetes accepted them because the objects
are valid. The refusal happens when Argo CD's controller evaluates them against the project,
and it surfaces as a **condition on the resource**, not as an error from `kubectl apply`.

**A pipeline that only checks whether `kubectl apply` succeeded will report both of these as
successful deployments.** That is the single most useful thing in this step.

Now one that is inside every boundary:

`kubectl apply -f /root/manifests/01-project/allowed.yaml`{{exec}}

`sleep 20 && kubectl get application tenant-a-web -n argocd`{{exec}}

It reconciles normally, because the repo is approved and `tenant-a-web` matches the
`tenant-a-*` glob.

## About external clusters

A project's `destinations` also names **which clusters** an Application may target. Registering
one with `argocd cluster add` creates a ServiceAccount on the target, binds it to a ClusterRole,
and stores a long-lived token back in the `argocd` namespace.

The default role is **cluster-admin equivalent**, which is why the `argocd` namespace is the
most security-sensitive namespace you operate: it holds credentials that can do anything on
every cluster you have registered. That is also the blast radius of one compromised Argo CD.

This lab is a single node, so there is no second cluster to register here. The mechanism is
worth knowing before you meet it.

<details><summary>No condition appeared yet?</summary>

The controller has to evaluate the Application first. Wait a few more seconds, or force it:

`argocd app get rejected-repo --hard-refresh`{{copy}}
</details>
