# Install Argo CD properly

> **Part of a full course.** This lab is the hands-on half of **Module 2** of
> [Argo CD for Beginners: Foundations and First Deployments](https://devoriales.com/quiz/26/argo-cd-for-beginners-foundations-first-deployments)
> on [devoriales.com](https://devoriales.com), a free course covering GitOps
> foundations, installation, the `Application` resource, and deploying with plain YAML,
> Kustomize and Helm.
>
> You can complete this lab on its own and it will make sense. The course adds the *why*
> around it, and a local k3d setup you keep for the rest of the modules.

Almost every Argo CD guide gives you the same two lines:

```
kubectl create namespace argocd
kubectl apply -n argocd -f .../stable/manifests/install.yaml
```

Run them and you will get an Argo CD that looks installed, answers on the UI, and
quietly cannot do ApplicationSets. The failure is printed once, in the middle of about
sixty lines of output, and then never mentioned again until something does not work
weeks later.

In this scenario you will hit that failure on purpose, understand exactly why it
happens, and fix it the way the Kubernetes API actually intends.

## What you will do

1. **Install Argo CD 3.4.5** and watch one object fail to apply
2. **Prove the install is healthy**, which is not the same thing as `kubectl wait` passing
3. **Reach the API server** and confirm which build is answering
4. **Log in and rotate the admin password**, then deal with the credential that rotation
   leaves behind

## Your environment

A single-node Kubernetes cluster, already running and ready. The `argocd` CLI is
installed, and the Argo CD container images are already pulled onto the node so your
install completes in seconds rather than minutes.

Argo CD itself is **not** installed. That is step 1.

Everything you run here is real. Nothing is simulated, and nothing is pre-baked to make
a command look like it worked.

Let's get into it.
