# Boundaries: what may deploy, who may act, and whether to trust the commit

Argo CD holds cluster-admin credentials. An Application is a request to use them, and
everything in this scenario is about the five things standing between that request and your
cluster.

Each one stops a different failure, and missing any one leaves a hole:

| Mechanism | Stops |
| --- | --- |
| `AppProject` restrictions | a tenant deploying into `kube-system`, or granting itself cluster-admin |
| RBAC `policy.csv` | a tenant syncing another tenant's Application |
| `sourceNamespaces` | a tenant needing write access to the `argocd` namespace |
| Sealed Secrets | a credential reaching Git in readable form |
| Signature verification | deploying a commit nobody authorised |

The common mistake is writing a careful `AppProject` and leaving RBAC at defaults, which
constrains what an app *does* while letting anyone sync anyone else's.

In the next 30 minutes you will:

- Watch a project **refuse two Applications for two different reasons**, and see that `kubectl apply` reported success both times
- Create a scoped RBAC role and test it with `argocd admin settings rbac can`, including the default that quietly grants every user read access to every project
- Let a tenant declare Applications in **their own namespace**, working through both gates, the first of which fails in total silence
- Seal a real Secret, apply the ciphertext, and watch the controller turn it back into a working Secret
- Require **signed commits**, watch an unsigned revision be refused, then prove that requirement was the only thing blocking it

## What is already set up

Argo CD 3.4.5 is installed with the `argocd` CLI in core mode. Sealed Secrets and `kubeseal` are installed for
step 4. `argocd-rbac-cm` is deliberately left **empty**, which is exactly how a stock install
ships, so step 2 can start from the real default.

Manifests are in `/root/manifests/`.

## One thing this lab cannot show you

Registering an **external cluster** needs a second Kubernetes cluster, and this environment is
a single node. Step 1 covers what a registration grants and why it matters, and the lab does
not pretend to perform one. Everything else here runs for real.

## Part of a course

This scenario covers Modules 7 and 8 of the free
[Argo CD for Beginners](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops)
course on devoriales.com, which continues into observability, progressive delivery and a
capstone platform.

Let's build a boundary and then try to cross it.
