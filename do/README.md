# do/

DigitalOcean App Platform, managed databases, and Cloudflare R2 for the
homelab. This replaces the Vultr VM in `vps/` once the migration is done.
Migration plan: https://claude.ai/artifact/J9V68fpDaSEizhRfW4ZU7H

## Status

Phase 2 of the migration: only the R2 buckets exist. The App Platform app and
the databases come in later PRs.

## Terraform

`do/terraform/` is applied by `.github/workflows/do-terraform.yaml`: plan on
pull requests, apply on merge to `main`. State lives in the HCP Terraform
workspace `homelab-do` (org `kitzy_net`, Local execution mode).

Secrets come from the 1Password `GitHub` vault:

| Item | Used for |
| --- | --- |
| `Terraform Cloud` | HCP state access |
| `Cloudflare R2 Terraform` | R2 bucket management (Workers R2 Storage Read + Write only) |

## R2 buckets

| Bucket | Holds |
| --- | --- |
| `kitzy-fleet-installers` | Fleet software installers, icons, bootstrap packages, org logos |
| `kitzy-homelab-backups` | restic repository for the nightly database dumps |

Both have `prevent_destroy`. Each bucket's object read/write token is created
outside Terraform, because creating tokens needs a permission that could mint
a token with any access. Those tokens live in 1Password.

S3 endpoint: `https://<account-id>.r2.cloudflarestorage.com`, region `auto`.
