# Matrix: every combination, and the arithmetic you should do first

`matrix` takes two generators and produces their **cross product**. The parameters from both
are available in the template at once.

`cat /root/manifests/03-matrix/appset-matrix.yaml`{{exec}}

Two environments, two regions. **Before applying it, work out the number.** Two times two is
four, so you should get four Applications named `mx-<env>-<region>`.

`kubectl apply -f /root/manifests/03-matrix/appset-matrix.yaml`{{exec}}

`kubectl get applications -n argocd -o name | grep mx-`{{exec}}

```
application.argoproj.io/mx-dev-eu
application.argoproj.io/mx-dev-us
application.argoproj.io/mx-staging-eu
application.argoproj.io/mx-staging-us
```

Four, exactly as predicted. That habit of predicting the count is the whole point of this step.

## Why the arithmetic matters

The realistic matrix is not list times list. It is **clusters times Git directories**: every
app in the repo, on every cluster you have registered.

- 3 environments across 4 clusters is **12** Applications from one object
- register a fifth cluster and it becomes **15**, with no edit anywhere

That is the feature. It is also how people accidentally generate sixty Applications and
wonder why the controller is slow and their cluster is full.

**If you cannot state the number before applying, do not apply it.** Start with a `list`, prove
the pattern, then convert.

There is a sibling worth knowing: `merge` combines generators **by a key** instead of
multiplying them, which is how you take a base set and override specific entries. Reach for
`merge` when you want "all of these, but prod is different", and `matrix` when you genuinely
want every combination.

## Generator sprawl, concretely

The failure is not that matrix is complicated. It is that the generator has no opinion about
intent:

- someone adds a directory meant for one environment, and it deploys to **all** of them
- someone registers a cluster for an experiment, and every app in the repo lands on it
- a glob picks up `_archive` and produces Applications that deploy nothing

None of those are errors. Every one is the generator doing exactly what it was told.

## Clean up before the next step

The next step generates three more Applications and is easier to read on a quiet cluster:

`kubectl delete applicationset matrix-demo git-demo cluster-demo -n argocd`{{exec}}

`kubectl get applications -n argocd`{{exec}}

Note how much disappeared from three delete commands. That is the blast radius from step 1,
seen at scale.

<details><summary>Counting a matrix that includes a Git generator</summary>

You cannot know the count from the manifest alone, because one side is discovered. Resolve it
first:

`kubectl get applicationset <name> -n argocd -o jsonpath='{.status.conditions[*].message}'`{{copy}}

Or apply it to a scratch cluster and count. Guessing on a production instance is how the
sixty-Application afternoon starts.
</details>
