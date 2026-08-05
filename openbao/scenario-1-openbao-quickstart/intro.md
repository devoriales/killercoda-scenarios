# OpenBao Quickstart

A secrets manager's job is not storing secrets. A database can store secrets. The job is
making the storage layer worthless to whoever steals it.

OpenBao does that with a **barrier**: everything is encrypted before it reaches disk, and
the key that decrypts it exists only in memory. That single design choice explains most of
the behaviour that surprises people the first time they run it, including a pod that starts
successfully and then refuses to become Ready.

In the next twenty minutes you will:

1. Deploy OpenBao on Kubernetes and see it come up **sealed**, which is correct
2. Initialize it, receive Shamir key shares, and unseal it
3. Write a secret, rotate it, and read the previous value back
4. Delete a version, undo that, then destroy one and discover you cannot

## What you have

A single-node Kubernetes cluster with `kubectl` and `helm` ready. The OpenBao chart repo is
added and the container image is already pulled, so your install will be quick.

OpenBao itself is **not** installed. That is step 1.

A `bao` command is on your PATH. It runs the real CLI inside the OpenBao pod once that pod
exists, so you can type `bao status` rather than a `kubectl exec` incantation every time.

## About this environment

This quickstart runs OpenBao over plain HTTP, because it is a throwaway browser VM and the
subject here is the seal lifecycle. The full course deploys with TLS on the listener from
the very first boot and explains why "we will add TLS later" is how a secrets manager ends
up serving plaintext for a year.

The lesson text, architecture diagrams, and knowledge checks live on devoriales.com:

**[OpenBao Secrets Management: Production Operations on Kubernetes](https://devoriales.com/quiz/27/openbao-secrets-management-production-operations-on-kubernetes)**

That course covers the same ground on a local k3d cluster you keep, then goes considerably
further: auto-unseal, seal migration, Raft clustering, dynamic database credentials, PKI,
and a capstone that ends with a deliberately triggered seal outage you have to recover from.

Let's get an instance running.
