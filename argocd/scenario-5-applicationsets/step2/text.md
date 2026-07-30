# Discovering the list instead of maintaining it

A List generator needs you to keep the list current. Two generators derive it instead.

## Git: directories become Applications

`cat /root/manifests/02-discover/appset-git.yaml`{{exec}}

The glob `envs/*` matches every folder under `envs/`. Apply it:

`kubectl apply -f /root/manifests/02-discover/appset-git.yaml`{{exec}}

`kubectl get applications -n argocd -o name | grep git-`{{exec}}

```
application.argoproj.io/git-dev
application.argoproj.io/git-prod
application.argoproj.io/git-staging
```

Nobody listed them. The generator scanned the glob and produced one parameter map per
matching directory. **Adding an environment is now adding a folder.**

The parameters a directory gives you:

| Parameter | For `envs/staging` |
| --- | --- |
| `{{path}}` | `module-06-applicationsets/03-git-generator/envs/staging` |
| `{{path.basename}}` | `staging` |

Use `{{path.basename}}` for names. `{{path}}` contains slashes and is not a legal Application
name.

There is a second mode that reads **config files** rather than folder names, where each
matched file is parsed and its contents become the parameters. Directories are simpler and
run out of room quickly: the moment prod needs a different replica count *and* a different
domain, you want `files`.

## The trap: it notices, and it also deletes

The generator re-scans on the controller's own interval, so a new directory appears within a
few minutes rather than immediately. In production you point a Git webhook at Argo CD instead
of shortening the interval.

The dangerous half is the other direction. **Renaming or deleting a directory deletes the
Application generated from it**, and with `prune: true` that takes the workload with it. A
directory rename in Git is a production deletion.

## Cluster: one Application per registered cluster

Now the one that surprises people. This cluster has **no external clusters registered at all**:

`kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster`{{exec}}

```
No resources found in argocd namespace.
```

Zero cluster secrets. So a `clusters: {}` generator should produce nothing, right?

`kubectl apply -f /root/manifests/02-discover/appset-cluster.yaml`{{exec}}

`kubectl get applications -n argocd -o name | grep cl-`{{exec}}

```
application.argoproj.io/cl-in-cluster
```

**One Application, from zero secrets.** The cluster Argo CD runs in is always a target, called
`in-cluster`, and it needs no secret because Argo CD reaches its own API server through its
ServiceAccount.

That matters practically: a `clusters` generator on a single-cluster install is not a no-op,
and it is a cheap way to see the generator work before you have a fleet.

Labels are what make it selective:

```yaml
    - clusters:
        selector:
          matchLabels:
            environment: production
```

Now registering a new production cluster deploys to it automatically, with no edit anywhere.

## One more, described rather than run

The **SCM Provider** generator queries a Git host's API and produces one parameter map per
repository in an organisation. It needs a token and a real organisation, so nothing here would
be reproducible on your cluster and this lab does not pretend to run it.

What matters conceptually: it is the only generator whose source of truth lives **outside**
your GitOps repository. A team creating a repo changes what is deployed. Powerful for
onboarding tenants automatically, and it means your deployment set depends on a token that
expires.

<details><summary>Why does the glob sometimes match too much?</summary>

`envs/*` matches every directory, including a `_archive` or a `README` folder if one is
sitting there. Each becomes an Application deploying whatever it contains, which is usually
nothing. Check what the generator resolved before blaming the template, and exclude
explicitly:

`  - path: 'envs/_*'`{{copy}}
`    exclude: true`{{copy}}
</details>
