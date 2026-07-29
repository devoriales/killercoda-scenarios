# Log in and rotate the admin password

Argo CD generated an admin password at install and put it in a Secret.

`kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d; echo`{{exec}}

A 16 character random string. Two things about that Secret matter immediately.

**Base64 is not encryption.** Anyone who can read Secrets in this namespace can read that
password. RBAC on the `argocd` namespace matters from minute one, not later.

**Its name says `initial`.** It exists to get you in once.

## Log in

`argocd login localhost:8080 --username admin --password "$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)" --insecure`{{exec}}

```
'admin:login' logged in successfully
```

Confirm who you are:

`argocd account get-user-info`{{exec}}

```
Logged In: true
Username: admin
Issuer: argocd
Groups:
```

`Issuer: argocd` means Argo CD authenticated you against its own local account rather
than an identity provider. When you configure SSO later, this field changes, and it is
the quickest way to prove SSO is genuinely in use rather than silently falling back to
the local admin.

`Groups:` is empty because local accounts have no group membership, which is why
group-based RBAC needs an external provider.

## Rotate it

`argocd account update-password --current-password "$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)" --new-password 'Killercoda!2026'`{{exec}}

Now prove it took, in both directions. The new password should authenticate:

`curl -sk -o /dev/null -w "new password: HTTP %{http_code}\n" -X POST https://localhost:8080/api/v1/session -H 'Content-Type: application/json' -d '{"username":"admin","password":"Killercoda!2026"}'`{{exec}}

And the old one should not:

`curl -sk -o /dev/null -w "old password: HTTP %{http_code}\n" -X POST https://localhost:8080/api/v1/session -H 'Content-Type: application/json' -d "{\"username\":\"admin\",\"password\":\"$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)\"}"`{{exec}}

```
new password: HTTP 200
old password: HTTP 401
```

Checking the second one matters as much as the first. A rotation that leaves the old
password working has not rotated anything.

## The part almost every guide skips

`kubectl get secret argocd-initial-admin-secret -n argocd`{{exec}}

**It is still there.** Rotating the password did not remove it, and it still holds the
old password in plaintext, readable by anyone with Secret access to this namespace.

The live credential moved somewhere else entirely:

`kubectl get secret argocd-secret -n argocd -o jsonpath='{.data}' | tr ',' '\n' | grep -o '"[a-zA-Z.]*"' | head -6`{{exec}}

`argocd-secret` now holds a bcrypt hash in `admin.password`, plus `admin.passwordMtime`
recording when it changed. Argo CD uses that timestamp to invalidate sessions issued
before the rotation.

Delete the leftover:

`kubectl delete secret argocd-initial-admin-secret -n argocd`{{exec}}

The retired password no longer authenticates, so the leftover is not directly
exploitable. Delete it anyway: people reuse passwords across environments, and a
credential-shaped object is exactly what gets copied into a runbook or a screenshot
later.

**Order matters.** Confirm the new password works *first*. Delete the bootstrap secret
before you can log in and you have locked yourself out of the only admin account.

<details><summary>Hint: locked yourself out?</summary>

Clear the hash and let Argo CD regenerate a fresh bootstrap secret:

```
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": null, "admin.passwordMtime": null}}'
kubectl -n argocd rollout restart deploy/argocd-server
```
</details>
