# App-of-apps: Argo CD managing Argo CD

Everything so far has been you applying an Application by hand. That does not scale: a
platform team running forty services does not want forty `kubectl apply` commands, and a
rebuilt cluster would need all forty run again in the right order.

An Application's `path` can point at a directory of **Application manifests** instead of
workloads. Argo CD then creates those Applications, and each one deploys its own workload.

`cat /root/manifests/04-app-of-apps/root-application.yaml`{{exec}}

Two details make it work:

- **`destination.namespace: argocd`**, because the things it creates are Argo CD objects,
  not workloads. Point this at `demo` and the children are created somewhere the controller
  is not watching, and nothing happens.
- **`syncPolicy.automated`**, so the children appear without a sync command.

Apply it:

`kubectl apply -f /root/manifests/04-app-of-apps/root-application.yaml`{{exec}}

Wait for the automated sync, then look at what exists:

`sleep 45 && kubectl get applications -n argocd`{{exec}}

```
NAME          SYNC STATUS   HEALTH STATUS
broken        Synced        Degraded
demo          Synced        Healthy
managed-web   Synced        Healthy
root          Synced        Healthy
```

**Nobody created `managed-web`.** It was declared in Git, `root` discovered it, and Argo CD
created it. Its workload is running too:

`kubectl get deploy -n demo`{{exec}}

Adding another service to this cluster is now a pull request against a directory. Rebuilding
the cluster from scratch is applying one file and waiting.

## The failure this pattern invites

Here is a real one, produced while building the course this scenario comes from.

The child Application was pointed at the **same path and namespace** as the standalone
`demo` Application. Both were valid, both synced, and then `demo` went `OutOfSync` while
staying `Healthy`, which is a strange looking pair.

The resources were fine. Ownership had moved. Remember the tracking-id from step 1:

`kubectl get deploy demo -n demo -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'`{{exec}}

```
demo:apps/Deployment:demo/demo
```

Yours still names `demo`, because the committed example gives each Application its own
path. In the broken version this annotation named the *other* Application: two apps claimed
the same Deployment, the newer one won, and the original was left comparing itself against
resources it no longer owned.

**Two Applications must never manage the same resources.** The symptom, an app that is
`OutOfSync` but `Healthy` with no visible diff, does not name its cause. The tracking-id
does.

## Where this goes

- **Bootstrapping**: a new cluster gets Argo CD plus one root Application and reconciles itself into existence
- **Environments**: one root per environment, each pointing at its own directory
- **Scale**: when the children start repeating themselves, an ApplicationSet generates them instead

That last one is Module 6 of the course. This pattern is where most teams start.
