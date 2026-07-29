# Install Argo CD (and watch it half-fail)

Argo CD ships as one large manifest. Create the namespace first:

`kubectl create namespace argocd`{{exec}}

## Install the way most guides tell you to

Note the URL: it carries a **version tag**, not `stable`. `stable` is a moving branch, so
applying it twice installs two different versions and nothing in your cluster records
which one you got. Pinning is the whole point of GitOps, so start as you mean to go on.

`kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.5/manifests/install.yaml`{{exec}}

Sixty-odd lines scroll past. Look at the **last** one:

```
The CustomResourceDefinition "applicationsets.argoproj.io" is invalid:
metadata.annotations: Too long: may not be more than 262144 bytes
```

Everything else applied. One CustomResourceDefinition did not.

## Why it failed

`kubectl apply` is *client-side* apply. To work out diffs later, it stores a copy of the
entire resource you submitted in an annotation called
`kubectl.kubernetes.io/last-applied-configuration`. Kubernetes caps annotations at
262144 bytes.

Confirm the damage is real and not cosmetic:

`kubectl get crd | grep argoproj`{{exec}}

```
applications.argoproj.io     2026-07-29T08:04:55Z
appprojects.argoproj.io      2026-07-29T08:04:56Z
```

Two CRDs, not three. `applicationsets.argoproj.io` was **never created**, so there is
nothing to inspect and nothing to repair. An Argo CD in this state runs happily and
silently ignores every ApplicationSet you create, which is why this is worth catching
now rather than in a month.

## Fix it with server-side apply

Let the API server compute the merge instead of the client. There is then no need to
stash the original anywhere, so the annotation limit stops applying:

`kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.5/manifests/install.yaml`{{exec}}

Now every line ends in `serverside-applied`, including the CRD that just failed.

## See what would not fit

The CRD exists now, so you can finally measure the thing client-side apply was trying to
stuff into an annotation:

`kubectl get crd applicationsets.argoproj.io -o json | wc -c`{{exec}}

Around **374000** bytes, against a 262144 byte ceiling. It was never going to fit.
Nothing was wrong with the manifest, your cluster, or your network.

(This only works now. Run it before the server-side apply and you get
`Error from server (NotFound)`, because the object the first apply failed to create does
not exist.)

`--force-conflicts` matters on this second run specifically: your first client-side apply
already claimed ownership of some fields, so the two mechanisms now disagree about who
owns what. The flag settles it.

Treat server-side apply as the default for Argo CD. It is not a workaround; it is the
mode Kubernetes intends for large, tool-managed objects.

<details><summary>Hint: nothing applied at all?</summary>

If every line errored rather than just the CRD, the namespace probably does not exist.
Run `kubectl get ns argocd` and create it if missing.
</details>
