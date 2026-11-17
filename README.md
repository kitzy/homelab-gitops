# homelab-gitops

Monorepo for managing the entire homelab as code.

## Overview

This repository is the single source of truth for the homelab. Each top-level directory owns one domain of the homelab and is managed declaratively and version-controlled:

| Directory | Domain | Status |
|-----------|--------|--------|
| [`compose/`](compose/) + [`.doco-cd.yml`](.doco-cd.yml) | Authentik, Fleet, and backups as Docker Compose stacks on `homelab-vps`, deployed by Doco-CD | Active |
| [`vps/`](vps/) | The Vultr VM (`homelab-vps`) via Terraform on HCP, plus its runbook | Active |
| [`tailscale/`](tailscale/) | Tailnet config (ACLs, DNS, keys) via Terraform on HCP | Active |
| [`dns/`](dns/) | Public DNS (Route53 + Cloudflare zones, Cloudflare Tunnel routes) via Terraform on HCP | Active |
| `proxmox/` | Proxmox VMs as code (Terraform) | Planned |
| `docker/` | Standalone Docker container configs | Planned |

The K3s cluster and its Flux setup (`kubernetes/`) were retired in November 2026, when the apps moved to `homelab-vps`. They are still in the git history.

## How changes ship

| Change | What happens |
|--------|--------------|
| `compose/**` or `.doco-cd.yml` | Doco-CD on `homelab-vps` polls `main` every 3 minutes and runs `docker compose up` for the changed stacks. Secrets come from 1Password (`Homelab` vault). |
| `vps/terraform/**` | GitHub Actions plans on the PR and applies on merge ([`vps-terraform.yaml`](.github/workflows/vps-terraform.yaml)). |
| `tailscale/**` | Plan on the PR, apply on merge ([`tailscale-terraform.yaml`](.github/workflows/tailscale-terraform.yaml)). |
| `dns/**` | Validate and plan on the PR, apply on merge ([`dns-validate.yaml`](.github/workflows/dns-validate.yaml), [`dns-sync.yaml`](.github/workflows/dns-sync.yaml)). |

Terraform state lives in HCP Terraform (organization `kitzy_net`, local execution mode). CI secrets come from the 1Password `GitHub` vault.

Image versions in `compose/` are pinned. Renovate opens PRs for updates (see [`renovate.json`](renovate.json)). Fleet updates include release candidates.

## Where to look

- **The VM, the stacks, backups, and the restore runbook:** [`vps/README.md`](vps/README.md)
- **Tailnet policy and setup:** [`tailscale/README.md`](tailscale/README.md)
- **DNS zones and tunnel records:** [`dns/README.md`](dns/README.md)

## Related documentation

- **Migration Project**: [Proxmox Infrastructure Migration Project](https://www.notion.so/27ef8d994cff8155b9c7e0776dd7c272)
- **Current Services**: [Docker Services (Current)](https://www.notion.so/ac72a6815fe745b4954b3b44bc80c9b4)
- **Service Dependencies**: [Service Dependencies](https://www.notion.so/4cead182b2ad45989fcc43303633afcf)
