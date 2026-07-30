# Proving a commit was authorised

Step 4 stopped a secret leaking into Git. This step deals with the opposite direction: **Git is
now the thing that changes production, so who is allowed to write to it?**

Branch protection and reviews are the usual answer, and they are enforced by the Git host. Argo
CD does not know whether they were on when a commit landed. It clones a repository and applies
what it finds. If someone pushed directly, or a token leaked, or the host was misconfigured for
an afternoon, the manifests still look perfectly valid.

An `AppProject` can require something the Git host cannot fake for you: **a commit signed by a
key you named in advance.**

## Requiring signatures

`cat /root/manifests/04-security/signed-only-project.yaml`{{exec}}

The whole mechanism is four lines:

```yaml
  signatureKeys:
    - keyID: 529B1138C45871B7
```

Any Application in this project may only deploy a revision signed by that key. Create it, and
point an ordinary Application at it:

`kubectl apply -f /root/manifests/04-security/signed-only-project.yaml`{{exec}}

`kubectl apply -f /root/manifests/04-security/unsigned-app.yaml`{{exec}}

The manifests it points at are the same ones every earlier scenario deployed successfully.

`sleep 25 && kubectl get application unsigned-app -n argocd -o jsonpath='sync=[{.status.sync.status}]{"\n"}{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}'`{{exec}}

```
sync=[OutOfSync]
ComparisonError: Target revision 92aaf109b1e8855f0d4aae5cf62a6e40b024a8ae in Git is not signed, but a signature is required
```

Your commit SHA will be whatever `main` points at when you run this. The rest of the message is
the point: **Argo CD resolved the revision, checked it for a signature, found none, and stopped
before rendering anything.**

## It is a gate, not a warning

`argocd app sync unsigned-app`{{exec}}

```
Message: ComparisonError: Target revision 92aaf109b1e8855f0d4aae5cf62a6e40b024a8ae in Git is not signed, but a signature is required
{"level":"fatal","msg":"Operation has completed with phase: Error","time":"..."}
```

The sync ends in `Error` and nothing is applied. Compare this with step 1: a project violation
there was also reported as a condition, and here too the enforcement happens at reconciliation
rather than at `kubectl apply` time. **Every Argo CD boundary in this scenario behaves that way.**
The manifest is always accepted; the refusal always arrives afterwards.

## Where the trusted keys live

The `keyID` above is a reference. The public key it names has to be imported into Argo CD,
which keeps them in a ConfigMap:

`kubectl get cm argocd-gpg-keys-cm -n argocd`{{exec}}

```
Error from server (NotFound): configmaps "argocd-gpg-keys-cm" not found
```

**A stock install has no trusted keys at all**, so on this cluster the requirement could never
be satisfied by any commit. You import a public key with `argocd gpg add --from <file>`, and
this scenario ships one to look at:

`head -3 /root/manifests/04-security/trusted-key.asc`{{exec}}

Only the **public** half is here, and only the public half is ever needed: verification is done
with the public key, and signing happens on a developer's machine or in CI with the private one.
A lab that shipped a private key would be demonstrating the exact mistake this module is about.

Note that `argocd gpg list` exits with a fatal error rather than an empty list when the
ConfigMap is absent, which reads like a broken CLI and is really just "nothing imported yet".
`kubectl get cm` above is the clearer check.

## Proving the gate is what stopped it

The important question with any deny is whether you have found the real cause. Remove the
requirement, and remember from step 3 that editing a project does not re-queue its Applications:

`kubectl patch appproject signed-only -n argocd --type json -p '[{"op":"remove","path":"/spec/signatureKeys"}]'`{{exec}}

`kubectl annotate application unsigned-app -n argocd argocd.argoproj.io/refresh=hard --overwrite`{{exec}}

`sleep 20 && kubectl get application unsigned-app -n argocd -o jsonpath='sync=[{.status.sync.status}] health=[{.status.health.status}] conditions=[{.status.conditions[*].message}]{"\n"}'`{{exec}}

```
sync=[OutOfSync] health=[Missing] conditions=[]
```

Same repository, same commit, same manifests, no error. The signature requirement was the only
thing blocking it.

**In production the fix is the opposite of what you just did.** You sign the commits, or you
scope `signatureKeys` to the projects that warrant it. Deleting the requirement to make a
deployment go through is how this control quietly stops existing, usually at 2am with a change
freeze on.

## What this does and does not buy you

**It gives you** a check that lives in your cluster, applies to every sync, and depends on
neither your Git host's configuration nor its availability. Someone who pushes to `main` with a
leaked token cannot deploy, because they cannot produce the signature.

**It does not give you** a code review. A signed commit proves who wrote it, not that what they
wrote is correct or wise. It is authenticity, not quality, and a compromised developer machine
signs malicious commits perfectly well.

The practical cost is real: every commit reaching those paths needs a signature, so CI needs a
signing key, and any contributor without one is blocked. Which is why `signatureKeys` belongs on
the projects that manage production and cluster-scoped resources, not on all of them.

<details><summary>Where does Argo CD check the signature, exactly?</summary>

At the **target revision**, not at each file. The revision resolved from `targetRevision` must
carry a valid signature from a trusted key, and signature verification only applies to Git
sources. Helm repositories and OCI charts are outside this mechanism.

That also means a signed merge commit covers the whole merge, which is the usual arrangement:
developers push unsigned commits to branches, and the protected branch is updated only by
signed merges from CI.
</details>
