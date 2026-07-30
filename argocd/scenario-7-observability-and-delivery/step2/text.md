# Which component's log names the cause

Argo CD is seven workloads. When a sync fails, the log you reach for first is usually the wrong
one, and the wrong one is convincing because it repeats the error without adding anything.

Break something on purpose:

`kubectl apply -f /root/manifests/02-logs/broken-repo.yaml`{{exec}}

`sleep 25 && kubectl get application broken-repo -n argocd -o jsonpath='sync=[{.status.sync.status}]{"\n"}{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}'`{{exec}}

```
sync=[Unknown]
ComparisonError: Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = failed to list refs: authentication required: Repository not found.
```

You could stop here, because this message is actually good. Often it is not, so work the habit.

## Count the errors before reading any

`kubectl logs statefulset/argocd-application-controller -n argocd --tail=500 | grep -c '"level":"error"'`{{exec}}

```
0
```

`kubectl logs deploy/argocd-repo-server -n argocd --tail=500 | grep -c '"level":"error"'`{{exec}}

```
1
```

**Zero and one.** The application controller, which owns the Application and reported the
failure, logged no error at all. The repo-server logged exactly one, and it is the cause.

That is not a quirk. **The controller is reporting what the repo-server told it.** Manifest
generation is the repo-server's job, so the controller has nothing to add.

## Read the one that matters

`kubectl logs deploy/argocd-repo-server -n argocd --tail=500 | grep '"level":"error"' | tail -1`{{exec}}

```
{"grpc.code":"Unknown","grpc.component":"server","grpc.error":"failed to list refs: authentication required: Repository not found.","grpc.method":"GenerateManifest","grpc.method_type":"unary","grpc.service":"repository.RepoServerService","level":"error","msg":"finished call","time":"..."}
```

Two fields do the work:

- **`grpc.method`** tells you what was being attempted. `GenerateManifest` means rendering from
  Git. `CommitHydratedManifests` would mean the Source Hydrator from Module 9.
- **`grpc.error`** is the underlying cause, unwrapped. `Repository not found` here.

Note what the error actually says: **`authentication required`**. The repository does not exist,
and Git cannot tell you that without revealing whether private repositories exist, so it asks for
credentials instead. A missing repository and a repository you lack access to look identical.
Check the spelling before you go hunting for a credential problem.

## Which log for which symptom

| Symptom | Start here | Because |
| --- | --- | --- |
| `ComparisonError`, "failed to load target state" | **repo-server** | it clones and renders |
| Sync applies but resources are wrong | application controller | it decides and applies |
| Cannot log in, UI or API errors | argocd-server | it serves the API |
| Generated Applications missing | applicationset-controller | it owns generators |
| A hook Job never ran | application controller, then the Job's own pod | |

The rule underneath it: **whoever produced the value is who knows why it is wrong.**
The component that reports a failure is often just relaying.

`kubectl delete application broken-repo -n argocd`{{exec}}

<details><summary>The repo-server log is huge and mostly noise</summary>

It logs every gRPC call at info level, so a busy instance is thousands of lines of `started
call` / `finished call`. Filter first, always:

`kubectl logs deploy/argocd-repo-server -n argocd --tail=2000 | grep '"level":"error"'`{{copy}}

If you need one Application's activity and not the whole server's, the controller log carries
the app name on every line, so start there to get a timestamp, then use it to narrow the
repo-server log.
</details>
