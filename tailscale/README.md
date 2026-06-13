# Tailscale (managed with Terraform)

This directory is a **Terraform root module** that manages the Tailscale tailnet as
code — currently the tailnet **policy file** (ACLs, grants, tags, SSH), with DNS,
auth keys, and device authorization planned (see [Roadmap](#roadmap)).

State and runs are handled by **HCP Terraform** (Terraform Cloud), VCS-driven: opening
a PR produces a speculative `plan`, merging to `main` runs `apply`.

> **Scope:** this manages tailnet-wide configuration. It is **separate** from the
> in-cluster [Tailscale Kubernetes Operator](../kubernetes/infrastructure/networking/tailscale/),
> which exposes K3s workloads to the tailnet and is managed by Flux. The two are unrelated.

## Files

| File | Purpose |
|------|---------|
| [`terraform.tf`](terraform.tf) | Terraform settings: HCP `cloud` backend + provider versions |
| [`providers.tf`](providers.tf) | Tailscale provider (OAuth via workspace env vars) |
| [`acl.tf`](acl.tf) | `tailscale_acl` resource — applies `policy.hujson` |
| [`policy.hujson`](policy.hujson) | The tailnet policy (HuJSON). Source of truth, applied verbatim. |

## How it works

```
  Edit tailscale/*.tf or policy.hujson
            │
   ┌────────┴─────────┐
   │   Pull request   │ ──►  HCP runs a speculative `terraform plan`
   │                  │       (posted as a check on the PR; nothing applied)
   └────────┬─────────┘
            │ merge to main
            ▼
   HCP runs `terraform apply`  ──►  Tailscale API  ──►  live tailnet
```

Because `policy.hujson` was seeded **verbatim** from the live tailnet, the first apply
just brings the resource under Terraform management and pushes an identical policy — a
no-op against the tailnet.

## One-time setup

### 1. Create the HCP Terraform workspace

1. Sign in to [HCP Terraform](https://app.terraform.io/) and note your **organization
   name** — then set it as `organization` in [`terraform.tf`](terraform.tf) (currently
   `kitzy`).
2. Create a **VCS-driven** workspace named **`homelab-tailscale`**, connected to the
   `kitzy/homelab-gitops` GitHub repo.
3. In the workspace **Settings → General**:
   - **Terraform Working Directory:** `tailscale`
   - **Apply Method:** Auto apply (so merges to `main` apply automatically)
4. In **Settings → Version Control**, set **trigger patterns** to `tailscale/**` so changes
   elsewhere in the monorepo don't queue runs here.

### 2. Create a Tailscale OAuth client

[OAuth clients](https://login.tailscale.com/admin/settings/oauth) → **Generate OAuth client**
with **write** scope for:

- `acl` — the policy file (required now)
- `dns` — DNS settings (for the planned DNS management)

Save the **Client ID** and **Client Secret**. (Broader scopes — `auth_keys`, `devices` —
get added when we add those resources; they require a tag on the client.)

### 3. Add credentials to the workspace

In the `homelab-tailscale` workspace → **Variables**, add two **environment variables**,
both marked **Sensitive**:

| Variable | Value |
|----------|-------|
| `TAILSCALE_OAUTH_CLIENT_ID` | the OAuth Client ID |
| `TAILSCALE_OAUTH_CLIENT_SECRET` | the OAuth Client Secret |

The provider reads these automatically — no Terraform variables or GitHub secrets needed.
(Recommended: keep a copy in the 1Password `GitHub` vault as the system of record.)

## Editing the policy or config

1. Edit [`policy.hujson`](policy.hujson) (or the `.tf` files) on a branch.
2. Open a PR — HCP posts a speculative `plan` as a check. Review the diff.
3. Merge to `main` — HCP applies it.

### Tags currently in use

| Tag | Owner | Used by |
|-----|-------|---------|
| `tag:k8s-operator` | — | Tailscale Kubernetes Operator (the operator device) |
| `tag:k8s` | `tag:k8s-operator` | Devices the operator creates to expose services |
| `tag:ci` | `autogroup:admin` | Ephemeral GitHub Actions node in the Flux reconcile workflow |

## Roadmap

Each surface is captured from the live tailnet first (same "verbatim, then manage"
discipline as the ACL), then added as its own resource/PR:

- [ ] **DNS** — `tailscale_dns_nameservers`, `tailscale_dns_preferences`, `tailscale_dns_search_paths`
- [ ] **Auth keys** — `tailscale_tailnet_key` (e.g. the operator/CI bootstrap keys)
- [ ] **Device authorization / posture** as needed

## Safety notes

- `policy.hujson` matches the live tailnet, so the first apply is a no-op.
- `overwrite_existing_content = true` lets Terraform manage the policy without a prior
  `terraform import`; it is safe here precisely because the committed policy is identical
  to what's live.
- The OAuth client is least-privilege (only the scopes listed above).
- `apply` runs on merge — treat `main` as production and review the PR plan every time.

## References

- [Tailscale Terraform provider](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [`tailscale_acl` resource](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs/resources/acl)
- [Tailnet policy file syntax](https://tailscale.com/kb/1337/policy-syntax)
- [HCP Terraform VCS-driven runs](https://developer.hashicorp.com/terraform/cloud-docs/run/ui)
