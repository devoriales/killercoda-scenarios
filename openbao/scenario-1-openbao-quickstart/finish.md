# Done

You deployed a secrets manager, initialized it, unsealed it with threshold cryptography, and
found out which kinds of deletion you can take back.

| Step | What you learned | The command that showed it |
|---|---|---|
| 1 | A sealed OpenBao runs and answers, but reports itself not Ready | `kubectl get pods -n openbao` |
| 2 | Shamir reconstructs at the threshold, not incrementally | `bao operator unseal` |
| 3 | Old versions stay readable, so rotation is a record, not a revocation | `bao kv get -version=1` |
| 4 | `delete` has an undo, `destroy` does not | `bao kv destroy` |

## Five things worth keeping

- **The storage backend is untrusted by design.** Everything is encrypted before it reaches
  disk. A stolen backup is an inconvenience, not an incident.
- **Unsealing obtains the root key into memory.** It does not decrypt storage, and it does
  not survive a restart. That is why every restart needs unsealing again.
- **A threshold means a threshold.** Holding one share of a two-share threshold leaves you
  exactly as far from the key as holding none.
- **Rotating a secret in K/V v2 does not invalidate the old one.** Invalidation on rotation
  is what dynamic secrets do.
- **`0/1 Running` is not always a problem.** Read what the readiness probe is actually
  measuring before you go looking for a bug.

## What this quickstart left out

Quite a lot, deliberately. OpenBao here ran over plain HTTP on a throwaway VM, as a single
replica, with a root token you used for everything.

None of that is how you would run it:

- **TLS from the first boot**, not added later. The full course deploys with cert-manager
  issuing the listener certificate on the very first install, and explains the
  chicken-and-egg problem that creates: OpenBao becomes your certificate authority, but it
  cannot issue the certificate protecting its own startup.
- **Auto-unseal**, so a restart at 3am does not require two humans to be reachable. And the
  distinction that catches everyone: recovery keys are not unseal keys, and cannot unseal an
  instance whose seal backend is down.
- **Raft clustering**, quorum, leader election, snapshots and restores.
- **Policies and authentication**, so "who can read this path" has an enforced answer
  instead of a root token.
- **Dynamic secrets**, where rotation actually revokes.

## Where the rest lives

**[OpenBao Secrets Management: Production Operations on Kubernetes](https://devoriales.com/quiz/27/openbao-secrets-management-production-operations-on-kubernetes)**

Five modules and a capstone, on a local k3d cluster you keep rather than a VM that
disappears. The lesson text, architecture diagrams, and knowledge checks live there. It
ends with a deliberately triggered seal outage and a recovery drill, on the theory that the
first time you recover a sealed cluster should not be the time it matters.

Runnable artifacts for every lesson:
**[github.com/devoriales/openbao-secrets-course](https://github.com/devoriales/openbao-secrets-course)**
