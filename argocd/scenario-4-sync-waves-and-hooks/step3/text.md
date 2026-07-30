# Hook deletion policies: find the default by measuring it

A hook Job that has run is rubbish, in the literal sense: it did its work and now it sits in
the namespace. `hook-delete-policy` decides when Argo CD takes it away.

| Policy | Argo CD deletes the hook |
| --- | --- |
| `BeforeHookCreation` | just before creating the next run of it |
| `HookSucceeded` | as soon as it succeeds |
| `HookFailed` | as soon as it fails |

One of those is the default. Rather than telling you which, this step measures it.

## Three identical hooks, three policies

The Application has three `PreSync` Jobs differing in exactly one line: one sets
`HookSucceeded`, one sets `BeforeHookCreation`, and one deliberately sets **no policy at all**.

`kubectl apply -f /root/manifests/03-policies/policies-application.yaml`{{exec}}

`argocd app sync policies`{{exec}}

All three run. Now look at what survived:

`kubectl get jobs -n demo | grep policies`{{exec}}

```
policies-beforecreation   Complete   1/1   9s
policies-nopolicy         Complete   1/1   9s
```

**`policies-succeeded` is already gone.** It succeeded, so `HookSucceeded` removed it during
the sync. The other two are still sitting there in `Complete` state.

## Now sync a second time

This is the measurement. Note the ages above, then:

`argocd app sync policies`{{exec}}

`kubectl get jobs -n demo -o custom-columns='NAME:.metadata.name,CREATED:.metadata.creationTimestamp' | grep policies`{{exec}}

Both remaining Jobs have a **new creation timestamp**, identical to each other.

The Job with no policy behaved exactly like the one that explicitly asked for
`BeforeHookCreation`, because **that is the default.** Argo CD deleted the old one and created
a new one, for both.

## Why that matters

The thing people fear does not happen. A hook without a policy does **not** pile up one Job
per sync, and it does **not** silently stop running because Kubernetes refused to mutate an
immutable pod template.

What you actually get is **one stale completed Job per hook**, sitting there until the next
sync. Clutter, not breakage.

## Choosing

`HookSucceeded` is tidy: the Job disappears the moment it works, and the namespace stays
clean. The cost is real and is the reason not to reach for it automatically: **the logs go
with it.** A hook that succeeded but did something surprising leaves nothing to read.

Leaving the default is better for anything whose output you might want afterwards, like a
migration. The last run stays available until the next deploy replaces it, which is usually
exactly the window you care about.

`HookFailed` deserves the most thought. Deleting a hook the moment it fails throws away the
evidence of why it failed, which is almost never what you want while debugging.

And the combination that is nearly always wrong:

```
argocd.argoproj.io/hook-delete-policy: HookSucceeded,HookFailed
```

That deletes the hook however it ends, so you can never see what happened.

<details><summary>Debugging a failing hook?</summary>

Take the deletion policy off temporarily and sync again. The failed Job will stay put:

`kubectl logs -n demo job/policies-nopolicy`{{copy}}

Note that deleting a Job deletes its pods, so `kubectl logs` has nothing to read even seconds
later. If a hook's output matters operationally, ship it somewhere during the run.
</details>
