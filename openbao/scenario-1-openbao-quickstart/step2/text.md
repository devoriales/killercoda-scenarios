# Initialize and unseal with Shamir key shares

Initialization is a one-time event. It generates the encryption key that protects your data,
wraps it in a keyring, wraps that in a root key, and finally splits the key that protects
the root key into shares using **Shamir's Secret Sharing**.

You choose how many shares exist and how many are needed. Three and two here:

`bao operator init -key-shares=3 -key-threshold=2 -format=json | tee /root/init.json`{{exec}}

You now have three unseal keys and a root token. In production these go to three different
people and the output is never written to a file.

**There is no recovery path.** Lose two of the three shares and the data is
AES-256-GCM ciphertext that nobody can read, ever. Not your cloud provider, not a support
contract, not the maintainers. The barrier is doing precisely the job you asked of it.

Check what changed:

`bao status`{{exec}}

```
Initialized     true
Sealed          true
Total Shares    3
Threshold       2
Unseal Progress 0/2
```

Initialized, still sealed. The keys exist but nobody has presented any.

## Unseal it

Feed it the first share:

`bao operator unseal $(jq -r '.unseal_keys_b64[0]' /root/init.json)`{{exec}}

Look at the output: `Sealed true`, and `Unseal Progress 1/2`.

Nothing has been unlocked. This is worth pausing on, because the counter is misleading if
you read it as a progress bar. With one share of a two-share threshold, OpenBao holds
information that reveals **nothing** about the unseal key. Not a weaker key, not a smaller
search space. Threshold cryptography is not cutting a key into pieces where each piece leaks
part of the secret. One share leaves you exactly as far from the key as zero shares.

Now the second:

`bao operator unseal $(jq -r '.unseal_keys_b64[1]' /root/init.json)`{{exec}}

```
Sealed          false
Total Shares    3
Threshold       2
```

The reconstruction happened at the threshold, not incrementally.

## The pod agrees

`kubectl get pods -n openbao`{{exec}}

```
NAME        READY   STATUS    RESTARTS   AGE
openbao-0   1/1     Running   0          3m
```

`1/1`, and still zero restarts. The readiness probe runs `bao status`, which now exits `0`.
Nothing about the container changed; what changed is that a key exists in its memory.

Save the root token so the next steps can use it:

`export BAO_TOKEN=$(jq -r '.root_token' /root/init.json)`{{exec}}

<details><summary>What does unsealing actually unlock?</summary>

Not the storage backend. The data on disk stays encrypted for the entire life of the
instance, sealed or unsealed.

Unsealing reconstructs the unseal key, uses it to decrypt the **root key**, and holds that
root key in memory. The root key decrypts the keyring, and the keyring holds the encryption
key that reads your data.

Which is why restarting the pod puts you straight back to sealed: the root key only ever
existed in memory, and there is no plaintext copy on disk to reload. Try it later if you
like, with `kubectl delete pod openbao-0 -n openbao`.

</details>
