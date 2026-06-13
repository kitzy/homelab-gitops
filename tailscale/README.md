# Tailscale tailnet policy (ACLs) as code

This directory is the source of truth for the **tailnet policy file** — the ACLs,
grants, tags, SSH rules, and posture definitions that govern the entire tailnet.
It is synced to Tailscale automatically via GitHub Actions.

> **Scope:** this manages tailnet-wide policy. It is **separate** from the in-cluster
> [Tailscale Kubernetes Operator](../kubernetes/infrastructure/networking/tailscale/),
> which exposes K3s workloads to the tailnet. The two are unrelated and managed
> independently.

## Files

| File | Purpose |
|------|---------|
| [`policy.hujson`](policy.hujson) | The tailnet policy file (HuJSON). Single source of truth. |

The sync workflow lives at [`.github/workflows/tailscale-acl.yaml`](../.github/workflows/tailscale-acl.yaml).

## How it works

```
  Edit tailscale/policy.hujson
            │
   ┌────────┴─────────┐
   │   Pull request   │ ──►  gitops-acl-action runs `action: test`
   │                  │       (validates + runs ACL tests, applies nothing)
   └────────┬─────────┘
            │ merge to main
            ▼
   gitops-acl-action `action: apply`  ──►  Tailscale API  ──►  live tailnet policy
```

- **Pull request** touching `tailscale/**` → `action: test`. Validates the policy and runs
  any `tests` blocks. Never modifies the tailnet. This is your safety gate.
- **Push to `main`** touching `tailscale/**` → `action: apply`. Re-validates, then pushes the
  policy to the tailnet. **The merge is the deploy.**

The `tailnet` input is `"-"`, which the Tailscale API resolves to the OAuth client's own
tailnet — so there's nothing tailnet-specific hardcoded. To pin an explicit tailnet, set it
to your tailnet name (e.g. `example.com` or `something.ts.net`) in the workflow.

## One-time setup

### 1. Create a Tailscale OAuth client

1. Go to the [OAuth clients](https://login.tailscale.com/admin/settings/oauth) page in the
   admin console.
2. **Generate OAuth client** with scope **`Policy File` → Write** (this is the only scope
   it needs — keep it minimal).
3. Save the **Client ID** and **Client Secret**.

### 2. Store the credentials in 1Password

Create an item named **`Tailscale ACL`** in the **`GitHub`** vault (the same vault the
Flux workflow reads from), with two fields:

| Field | Value |
|-------|-------|
| `OAUTH_CLIENT_ID` | the OAuth Client ID |
| `OAUTH_SECRET`    | the OAuth Client Secret |

A dedicated item keeps the policy-file-write scope isolated from the broader
operator/CI OAuth credentials in the existing `Tailscale` item.

The workflow reads these via the `OP_SERVICE_ACCOUNT_TOKEN` GitHub secret already
configured for this repo (see `flux-reconcile.yaml`), using the references:

```
op://GitHub/Tailscale ACL/OAUTH_CLIENT_ID
op://GitHub/Tailscale ACL/OAUTH_SECRET
```

That's it — no additional GitHub secrets are needed beyond the existing
`OP_SERVICE_ACCOUNT_TOKEN`.

## Editing the policy

1. Edit [`policy.hujson`](policy.hujson) on a branch.
2. Open a PR — the **test** run validates it without touching the tailnet.
3. Merge to `main` — the **apply** run pushes it live.

### Tags currently in use

| Tag | Owner | Used by |
|-----|-------|---------|
| `tag:k8s-operator` | — | Tailscale Kubernetes Operator (the operator device) |
| `tag:k8s` | `tag:k8s-operator` | Devices the operator creates to expose services |
| `tag:ci` | `autogroup:admin` | Ephemeral GitHub Actions node in the Flux reconcile workflow |

### Adding ACL tests

The policy supports a `tests` block that the `test` run enforces on every PR. Adding tests
is the best protection against accidentally locking yourself out:

```hujson
"tests": [
  { "src": "tag:ci", "accept": ["tag:k8s:443"] },
],
```

## Safety notes

- The policy committed here was seeded **verbatim** from the live tailnet, so the first
  `apply` is a no-op.
- The OAuth client only has **Policy File write** scope — it cannot touch devices, keys, or
  DNS.
- Because `apply` runs on merge, treat `main` as production. Use PRs (and ACL `tests`) for
  every change.

## References

- [Tailscale GitOps for ACLs](https://tailscale.com/kb/1204/gitops)
- [`tailscale/gitops-acl-action`](https://github.com/tailscale/gitops-acl-action)
- [Tailnet policy file syntax](https://tailscale.com/kb/1337/policy-syntax)
- [Grants](https://tailscale.com/kb/1324/grants) · [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh)
