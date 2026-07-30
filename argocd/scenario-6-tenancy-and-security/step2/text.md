# RBAC: who may act on it

The project says what an Application may do. RBAC says **who may act on it**, and these are
completely separate systems. A user who cannot sync is being stopped by Argo CD, not by
Kubernetes, and no `kubectl` RoleBinding will fix it.

## What a stock install ships

`kubectl get cm argocd-rbac-cm -n argocd -o jsonpath='{.data}{"\n"}'`{{exec}}

Empty. All behaviour comes from built-in defaults, and there is exactly one account:

`argocd account list`{{exec}}

```
NAME   ENABLED  CAPABILITIES
admin  true     login
```

One shared admin, no policy. That is the thing to fix before anyone else logs in.

## Two ConfigMaps, easy to mix up

| ConfigMap | Holds |
| --- | --- |
| `argocd-cm` | **who exists**: local accounts, SSO connectors |
| `argocd-rbac-cm` | **what they may do**: policies and role bindings |

Create an account, which lives in the first:

`kubectl patch cm argocd-cm -n argocd --type merge -p '{"data":{"accounts.developer":"login"}}'`{{exec}}

Now the policy, in the second:

`kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{"data":{"policy.default":"role:readonly","policy.csv":"p, role:dev, applications, get, tenant-a/*, allow\np, role:dev, applications, sync, tenant-a/*, allow\np, role:dev, applications, delete, tenant-a/*, deny\np, role:dev, exec, create, tenant-a/*, deny\ng, developer, role:dev\n"}}'`{{exec}}

`kubectl rollout restart deploy argocd-server -n argocd`{{exec}}

`kubectl rollout status deploy argocd-server -n argocd --timeout=180s`{{exec}}

`argocd account list`{{exec}}

Two accounts now.

## Reading policy.csv

Two line types. `p` is a permission, `g` is a grant assigning a subject to a role.

A `p` line reads **subject, resource, action, object, effect**:

```
p, role:dev, applications, sync, tenant-a/*, allow
```

The object is where projects come in. `tenant-a/*` means "any Application in the `tenant-a`
AppProject", which is what makes AppProjects the tenancy boundary rather than just a
validation tool.

Note `exec, create` denied. `exec` opens a shell inside a running container, which bypasses
every boundary step 1 built. `logs` is debugging; `exec` is a way around the fence.

## Test the policy instead of reasoning about it

This is the command worth remembering, because reasoning about RBAC in your head is
unreliable:

`argocd admin settings rbac can developer sync applications 'tenant-a/anything' --namespace argocd`{{exec}}

```
Yes
```

Now the cases you expect to fail:

`argocd admin settings rbac can developer delete applications 'tenant-a/anything' --namespace argocd`{{exec}}

`argocd admin settings rbac can developer sync applications 'tenant-b/anything' --namespace argocd`{{exec}}

Both `No`. The first because of the explicit `deny`, the second because nothing granted it.

## Now the one that should worry you

`argocd admin settings rbac can developer get applications 'tenant-b/anything' --namespace argocd`{{exec}}

```
Yes
```

**Read access to another tenant's project**, which nothing in `role:dev` mentions.

`policy.default: role:readonly` applies to every request no explicit rule matched. So a
carefully scoped `policy.csv` still leaks read access across every project, including
repository URLs and image tags. Most teams ship exactly this.

For a genuinely closed system:

`kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{"data":{"policy.default":""}}'`{{exec}}

`kubectl rollout restart deploy argocd-server -n argocd && kubectl rollout status deploy argocd-server -n argocd --timeout=180s`{{exec}}

`argocd admin settings rbac can developer get applications 'tenant-b/anything' --namespace argocd`{{exec}}

```
No
```

Closed. Do this deliberately, because a user matching no rule now sees an empty Argo CD and
will report it as broken.

Precedence, worth memorising: **an explicit `deny` beats an `allow`** whatever the order, and
`policy.default` applies only when nothing else matched.

<details><summary>Under SSO, what is the subject?</summary>

Whatever your provider sends, which is often an email or a prefixed group like
`devoriales:platform` rather than a username. A `g` line that does not match exactly is not an
error: the grant silently never applies and the user falls through to `policy.default`. Verify
with:

`argocd account get-user-info`{{copy}}
</details>
