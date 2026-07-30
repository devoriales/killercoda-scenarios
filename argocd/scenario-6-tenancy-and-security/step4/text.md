# Committing a secret without committing the secret

GitOps has one uncomfortable consequence: **if the cluster's desired state lives in Git, the
secrets are part of the desired state.** And a Git repository is the worst possible place for
a plaintext credential. It is replicated to every clone, kept in history after you delete it,
and readable by everyone with pull access.

## base64 is not encryption, and it never was

A Kubernetes Secret stores values base64 encoded, which reads as scrambled and fools people
constantly. Apply one and look:

`kubectl apply -f /root/manifests/04-security/plain-secret.yaml`{{exec}}

`kubectl get secret db-password -n sealed-demo -o jsonpath='{.data.password}{"\n"}'`{{exec}}

```
aHVudGVyMi10aGUtcmVhbC1wYXNzd29yZA==
```

Now decode it. No key, no credential, nothing but a pipe:

`kubectl get secret db-password -n sealed-demo -o jsonpath='{.data.password}' | base64 -d; echo`{{exec}}

```
hunter2-the-real-password
```

**`base64` is an encoding, not a cipher.** It exists so binary values survive YAML, and
`base64 -d` is available on every machine on earth. Committing that manifest publishes the
password.

## Sealing it

[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) is already running in this
cluster. Its controller holds a private key; `kubeseal` encrypts with the matching public one.
Delete the plaintext Secret and seal the manifest instead:

`kubectl delete secret db-password -n sealed-demo`{{exec}}

`kubeseal --controller-namespace kube-system --format yaml < /root/manifests/04-security/plain-secret.yaml > /root/sealed-secret.yaml`{{exec}}

`cat /root/sealed-secret.yaml`{{exec}}

```
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: db-password
  namespace: sealed-demo
spec:
  encryptedData:
    password: AgDDD10GIlDix8L9++hSEZADHcCnlPKkEA+wd0hixinoj447cjFqDH1CP...
  template:
    metadata:
      creationTimestamp: null
      name: db-password
      namespace: sealed-demo
    type: Opaque
```

Your ciphertext will differ from the block above on every run, and that is correct: the
encryption is randomised, so sealing the same input twice produces two different outputs.

**That file is safe to commit.** Only the controller's private key decrypts it, and that key
never leaves the cluster.

## The round trip

`kubectl apply -f /root/sealed-secret.yaml`{{exec}}

`sleep 6 && kubectl get sealedsecret,secret -n sealed-demo`{{exec}}

```
NAME                                   AGE
sealedsecret.bitnami.com/db-password   6s

NAME                 TYPE     DATA   AGE
secret/db-password   Opaque   1      6s
```

**You applied one object and got two.** The controller watched the SealedSecret, decrypted it,
and created a normal Kubernetes Secret from it. Confirm the value survived intact:

`kubectl get secret db-password -n sealed-demo -o jsonpath='{.data.password}' | base64 -d; echo`{{exec}}

```
hunter2-the-real-password
```

Nothing downstream needs to know about any of this. Pods mount the Secret the usual way,
because it **is** the usual thing.

## Why this composes with Argo CD

The generated Secret is owned by the SealedSecret:

`kubectl get secret db-password -n sealed-demo -o jsonpath='{range .metadata.ownerReferences[*]}{.kind}/{.name}{"\n"}{end}'`{{exec}}

```
SealedSecret/db-password
```

Which means the controller treats it as its own and keeps it correct. Delete it:

`kubectl delete secret db-password -n sealed-demo`{{exec}}

`sleep 8 && kubectl get secret db-password -n sealed-demo`{{exec}}

```
NAME          TYPE     DATA   AGE
db-password   Opaque   1      8s
```

Back, in seconds. This is the same self-healing idea as Argo CD's, one layer down, and it is
why the two fit together: **Argo CD reconciles the SealedSecret from Git, and the Sealed
Secrets controller reconciles the Secret from the SealedSecret.** Argo CD never sees the
plaintext and never needs to.

Note the division of labour. Argo CD's `selfHeal` would restore a SealedSecret someone
deleted; it could not restore the Secret, because the Secret is not in Git at all.

## The part that surprises people

**The sealing key is specific to this cluster.** The controller generated its own keypair on
first start:

`kubectl get secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key`{{exec}}

```
NAME                      TYPE                DATA   AGE
sealed-secrets-keyw9s9t   kubernetes.io/tls   2      21h
```

The random suffix and age will differ on your cluster. A SealedSecret sealed against this cluster **cannot** be decrypted by another one. That is the
security property, and it is also the operational trap: rebuild the cluster without backing up
that key and every SealedSecret in your repository becomes undecryptable ciphertext. The
manifests still apply cleanly and no Secret is ever created.

**Back up the sealing key the day you install the controller**, not the day you need it.

<details><summary>kubeseal reports "cannot fetch certificate"</summary>

It defaults to looking for the controller in the `kube-system` namespace under the name
`sealed-secrets-controller`. This install matches, which is why the flag above is enough. On a
Helm install the name is usually different, and you point at it explicitly:

`kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets --format yaml < secret.yaml`{{copy}}
</details>
