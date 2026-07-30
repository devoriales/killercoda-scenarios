# One object, three Applications

A generator produces **parameter maps**. That is all any generator ever does, whatever its
source: a list of maps. The template is then rendered once per map, with `{{key}}` substituted.

`cat /root/manifests/01-list/appset-list.yaml`{{exec}}

Three elements, and a template whose name contains `{{env}}`:

```yaml
  generators:
    - list:
        elements:
          - env: dev
          - env: staging
          - env: prod
  template:
    metadata:
      name: 'list-{{env}}'
```

Apply it and watch:

`kubectl apply -f /root/manifests/01-list/appset-list.yaml`{{exec}}

`kubectl get applications -n argocd`{{exec}}

```
NAME           SYNC STATUS   HEALTH STATUS
list-dev       Synced        Healthy
list-prod      Synced        Healthy
list-staging   Synced        Healthy
```

Three Applications from one object you wrote once. Run it again after a few seconds if only
one or two have appeared yet.

The workloads differ, because each Application points at a different folder:

`kubectl get deploy -n demo`{{exec}}

```
web-dev       1/1
web-prod      3/3
web-staging   2/2
```

## The name must vary, or you get one Application

This is the mistake everyone makes once:

```yaml
    metadata:
      name: 'list-app'      # no parameter
```

Three elements now generate three Applications **with the same name**, which is not three
Applications. It is one, rewritten three times, and whichever element the controller
processed last wins. Nothing errors, so the symptom reads as "only one Application appeared"
and sends you looking at the generator.

## Generated Applications are owned

`kubectl get application list-dev -n argocd -o jsonpath='{range .metadata.ownerReferences[*]}{.kind}/{.name} controller={.controller}{"\n"}{end}'`{{exec}}

```
ApplicationSet/list-demo controller=true
```

That owner reference is the whole relationship, and it has a consequence worth internalising
before you use this in anger.

**Deleting the ApplicationSet deletes every Application it generated.** Not orphans them.
Deletes them. And because these Applications use `prune: true`, the workloads go too.

You can test that safely here, and it is worth doing so the lesson lands:

`kubectl delete applicationset list-demo -n argocd`{{exec}}

`kubectl get applications -n argocd`{{exec}}

All three gone. On a shared cluster, `kubectl delete applicationset` looks like a small
tidy-up command and is a fleet-wide deletion. Two mitigations exist:
`syncPolicy.preserveResourcesOnDeletion: true` keeps the underlying resources, and
`applicationsetcontroller.policy: create-update` stops the controller deleting anything at all.

Now put it back, because the next steps assume nothing about this one:

`kubectl apply -f /root/manifests/01-list/appset-list.yaml`{{exec}}

<details><summary>Nothing appeared at all?</summary>

When an ApplicationSet produces no Applications, the problem is one layer above where you are
looking. Read its own conditions and the controller log, in that order:

`kubectl get applicationset list-demo -n argocd -o jsonpath='{.status.conditions[*].message}'`{{copy}}
</details>
