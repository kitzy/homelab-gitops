# homelab-gitops

Monorepo for managing the entire homelab as code.

## Overview

This repository is the single source of truth for the homelab. Each top-level directory owns one domain of the homelab and is managed declaratively and version-controlled:

| Directory | Domain | Status |
|-----------|--------|--------|
| [`do/`](do/) | Authentik, Fleet, and backups on DigitalOcean App Platform with managed MySQL and Postgres, plus Cloudflare R2, via Terraform on HCP | Active |
| [`authentik/`](authentik/) | Authentik configuration (applications, providers, sources, login flows) via Terraform on HCP | Active |
| [`tailscale/`](tailscale/) | Tailnet config (ACLs, DNS, keys) via Terraform on HCP | Active |
| [`dns/`](dns/) | Public DNS (Route53 + Cloudflare zones) via Terraform on HCP | Active |
| `proxmox/` | Proxmox VMs as code (Terraform) | Planned |
| `docker/` | Standalone Docker container configs | Planned |

History, all November 2026 and all still in the git history: the K3s cluster and Flux (`kubernetes/`) gave way to a Vultr VM running Docker Compose with Doco-CD (`compose/`, `vps/`), which gave way on 18 November to DigitalOcean App Platform (`do/`).

## How changes ship

| Change | What happens |
|--------|--------------|
| `do/terraform/**` or `do/backup/**` | Plan on the PR, apply on merge, which redeploys the affected App Platform apps; changes to `do/backup/` also force a rebuild of the backup worker ([`do-terraform.yaml`](.github/workflows/do-terraform.yaml)). |
| `authentik/terraform/**` | Plan on the PR, apply on merge ([`authentik-terraform.yaml`](.github/workflows/authentik-terraform.yaml)). |
| `tailscale/**` | Plan on the PR, apply on merge ([`tailscale-terraform.yaml`](.github/workflows/tailscale-terraform.yaml)). |
| `dns/**` | Validate and plan on the PR, apply on merge ([`dns-validate.yaml`](.github/workflows/dns-validate.yaml), [`dns-sync.yaml`](.github/workflows/dns-sync.yaml)). |

Terraform state lives in HCP Terraform (organization `kitzy_net`, local execution mode). CI secrets come from the 1Password `GitHub` vault.

Image versions in `do/terraform/app.tf` and `do/backup/Dockerfile` are pinned. Renovate opens PRs for updates (see [`renovate.json`](renovate.json)). Fleet updates include release candidates; Authentik updates go one release line at a time.

## Where to look

- **The apps, databases, updates, backups, and disaster recovery:** [`do/README.md`](do/README.md)
- **Authentik configuration:** [`authentik/README.md`](authentik/README.md)
- **Tailnet policy and setup:** [`tailscale/README.md`](tailscale/README.md)
- **DNS zones and tunnel records:** [`dns/README.md`](dns/README.md)

## Related documentation

- **Migration Project**: [Proxmox Infrastructure Migration Project](https://www.notion.so/27ef8d994cff8155b9c7e0776dd7c272)
- **Current Services**: [Docker Services (Current)](https://www.notion.so/ac72a6815fe745b4954b3b44bc80c9b4)
- **Service Dependencies**: [Service Dependencies](https://www.notion.so/4cead182b2ad45989fcc43303633afcf)
