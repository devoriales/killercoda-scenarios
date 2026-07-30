# Knowing what broke, and what runs on top of a sync

The first six scenarios built a platform and locked it down. This one is about the day after:
something is `OutOfSync` and you do not know why, a sync fails and the error is in a component
you did not think to check, and "the deployment succeeded" turns out not to mean the application
works.

Then two layers that sit above a plain sync: a canary that stops and waits for a human, and a
platform that creates itself from a single file.

Every failure here is produced on purpose and then diagnosed, because the useful skill is not
knowing that Argo CD has logs. It is knowing **which** log, and what a status is actually
claiming.

In the next 35 minutes you will:

- Meet a diff whose only content is a bookkeeping annotation, and learn that this is the one kind of drift that never resolves itself
- Count error lines across two components and find that the one reporting the failure logged nothing at all
- Read the metric endpoint directly, and see why the obvious queue metric name returns no data and looks healthy
- Run a real canary that pauses at 25 percent, and find out which health status Argo CD reports while it waits
- Apply one file and watch a project, two Applications, two namespaces and two Deployments appear, then delete a child and watch it come back

## What is already set up

Argo CD 3.4.5 with the `argocd` CLI in core mode, and **Argo Rollouts 1.9.1** with its `kubectl
argo rollouts` plugin, because step 4 runs a canary rather than describing one.

Manifests are in `/root/manifests/`. Steps 4 and 5 deploy from the public course repository, so
you are reading the same files the course does.

## A note on what you will see

Three of the five steps start by breaking something. If a command reports an error, that is
usually the point of the command. The step text says plainly when output is expected to be
alarming.

## Part of a course

This scenario covers Modules 10, 11 and 12 of the free
[Argo CD for Beginners](https://devoriales.com/quiz/26/argo-cd-for-beginners-from-first-sync-to-production-gitops)
course on devoriales.com.

Let's break something and find out where it says so.
