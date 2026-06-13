# Tailscale (managed with Terraform)

This directory is a **Terraform root module** that manages the Tailscale tailnet as
code — currently the tailnet **policy file** (ACLs, grants, tags, SSH), with DNS,
auth keys, and device authorization planned (see [Roadmap](#roadmap)).

It follows the same pattern as [`kitzy/dns`](https://github.com/kitzy/dns): **HCP
Terraform holds the remote state** (local execution mode), and **GitHub Actions** runs
`plan` on PRs and `apply` on merge. Secrets come from 1Password, matching the repo's
existing [`flux-reconcile.yaml`](../.github/workflows/flux-reconcile.yaml).

> **Scope:** this manages tailnet-wide configuration. It is **separate** from the
> in-cluster [Tailscale Kubernetes Operator](../kubernetes/infrastructure/networking/tailscale/),
> which exposes K3s workloads to the tailnet and is managed by Flux. The two are unrelated.

## Files

| File | Purpose |
|------|---------|
| [`terraform.tf`](terraform.tf) | HCP `cloud` backend (org `kitzy_net`, workspace `homelab-tailscale`) + provider versions |
| [`providers.tf`](providers.tf) | Tailscale provider (OAuth via env vars) |
| [`acl.tf`](acl.tf) | `tailscale_acl` resource — applies `policy.hujson` |
| [`dns.tf`](dns.tf) | `tailscale_dns_preferences` — MagicDNS (the only DNS setting currently in use) |
| [`tailnet-settings.tf`](tailnet-settings.tf) | `tailscale_tailnet_settings` — tailnet-wide admin settings; locks ACL editing to GitOps |
| [`contacts.tf`](contacts.tf) | `tailscale_contacts` — account/support/security contact emails |
| [`policy.hujson`](policy.hujson) | The tailnet policy (HuJSON). Source of truth, applied verbatim. |

The workflow lives at [`.github/workflows/tailscale-terraform.yaml`](../.github/workflows/tailscale-terraform.yaml).

## How it works

```
  Edit tailscale/*.tf or policy.hujson
            │
   ┌────────┴─────────┐
   │   Pull request   │ ──►  GitHub Actions: fmt + validate + `terraform plan`
   │                  │       (state read from HCP; nothing applied)
   └────────┬─────────┘
            │ merge to main
            ▼
   GitHub Actions: `terraform apply`  ──►  Tailscale API  ──►  live tailnet
                         │
                         └─ state stored in HCP Terraform (kitzy_net / homelab-tailscale)
```

HCP runs in **local execution mode**: the GitHub Actions runner executes Terraform and
only uses HCP to store/lock state. Because `policy.hujson` was seeded **verbatim** from
the live tailnet, the first apply just brings the resource under management and pushes an
identical policy — a no-op against the tailnet.

## One-time setup

### 1. Create the HCP workspace (state only)

1. In [HCP Terraform](https://app.terraform.io/), under organization **`kitzy_net`**,
   create a workspace named **`homelab-tailscale`**.
2. Choose the **CLI-driven** workflow (no VCS connection — GitHub Actions drives runs).
3. In **Settings → General**, set **Execution Mode: Local** (same as the `dns` workspace).

### 2. Create a Tailscale OAuth client

[OAuth clients](https://login.tailscale.com/admin/settings/oauth) → **Generate OAuth client**
with **write** scope for:

- `acl` — the policy file (required now)
- `dns` — DNS settings (for the planned DNS management)

(Broader scopes — `auth_keys`, `devices` — get added when we add those resources; they
require a tag on the client.)

### 3. Add secrets to 1Password (vault `GitHub`)

The workflow reads these via the existing `OP_SERVICE_ACCOUNT_TOKEN` GitHub secret — no
new GitHub secrets needed:

| 1Password reference | Value |
|---------------------|-------|
| `op://GitHub/Terraform Cloud/credential` | HCP Terraform API token (a **user/team API token** from HCP → Account settings → Tokens) |
| `op://GitHub/Tailscale ACL/OAUTH_CLIENT_ID` | Tailscale OAuth Client ID |
| `op://GitHub/Tailscale ACL/OAUTH_SECRET` | Tailscale OAuth Client Secret |

Create the items/fields to match those references (item `Terraform Cloud` with field
`credential`, item `Tailscale ACL` with fields `OAUTH_CLIENT_ID` / `OAUTH_SECRET`).

## Editing the policy or config

1. Edit [`policy.hujson`](policy.hujson) (or the `.tf` files) on a branch.
2. Open a PR — the **plan** job posts the diff. Review it.
3. Merge to `main` — the **apply** job pushes it live.

### Tags currently in use

| Tag | Owner | Used by |
|-----|-------|---------|
| `tag:k8s-operator` | — | Tailscale Kubernetes Operator (the operator device) |
| `tag:k8s` | `tag:k8s-operator` | Devices the operator creates to expose services |
| `tag:ci` | `autogroup:admin` | Ephemeral GitHub Actions node in the Flux reconcile workflow |

## Roadmap

Each surface is captured from the live tailnet first (same "verbatim, then manage"
discipline as the ACL), then added as its own resource/PR:

- [x] **Tailnet settings** (`tailscale_tailnet_settings`) — incl. locking ACL editing to GitOps
- [x] **Contacts** (`tailscale_contacts`)
- [x] **DNS — MagicDNS** (`tailscale_dns_preferences`) — managed in `dns.tf`
- [ ] **DNS — nameservers / search paths / split-DNS** — currently empty on the tailnet;
      add `tailscale_dns_nameservers` / `tailscale_dns_search_paths` /
      `tailscale_dns_split_nameservers` when a resolver or internal domains are configured
- [ ] **Auth keys** — `tailscale_tailnet_key` (e.g. the operator/CI bootstrap keys)
- [ ] **Device authorization / posture** as needed

## Safety notes

- `policy.hujson` matches the live tailnet, so the first apply is a no-op (verified
  byte-for-byte against the live policy via the API before enabling automation).
- `overwrite_existing_content = true` (in `acl.tf`) lets Terraform manage the policy
  without a prior `terraform import`; it is safe here precisely because the committed
  policy is identical to what's live.
- The OAuth client is least-privilege (only the scopes listed above).
- `apply` runs on merge — treat `main` as production and review the PR plan every time.
- **ACL editing is locked to GitOps** (`acls_externally_managed_on = true` in
  `tailnet-settings.tf`): the admin-console policy editor is read-only, so all ACL
  changes must go through this repo. If CI is ever broken and you need an emergency
  console hotfix, set that flag back to `false` first (via a PR, or temporarily in the
  console once unlocked).

## References

- [Tailscale Terraform provider](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [`tailscale_acl` resource](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs/resources/acl)
- [Tailnet policy file syntax](https://tailscale.com/kb/1337/policy-syntax)
- [`kitzy/dns`](https://github.com/kitzy/dns) — the sibling repo this pattern mirrors
