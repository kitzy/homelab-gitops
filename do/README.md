# do/

DigitalOcean App Platform, managed databases, and Cloudflare R2 for the
homelab. This replaces the Vultr VM in `vps/` once the migration is done.
Migration plan: https://claude.ai/artifact/J9V68fpDaSEizhRfW4ZU7H

## Status

Phase 4 of the migration (rehearsal). The databases, the R2 buckets and the
App Platform app exist. The app runs on empty databases at
auth-do.kitzy.net and fleet-do.kitzy.net (`local.rehearsal` in
`terraform/app.tf`). Production stays on the Vultr VM until the cutover.

## Apps (region nyc)

Three App Platform apps, so each deploys, fails and rolls back on its own.

| App | Component | Kind | Size |
| --- | --- | --- | --- |
| `authentik` | `authentik-server` | service, port 9000 | apps-s-1vcpu-1gb-fixed |
| | `authentik-worker` | worker | apps-s-1vcpu-0.5gb |
| `fleet` | `fleet` | service, port 8080 | apps-s-1vcpu-1gb-fixed |
| | `fleet-migrate` | PRE_DEPLOY job (`fleet prepare db`) | apps-s-1vcpu-0.5gb |
| | `redis` | internal service, port 6379 | apps-s-1vcpu-0.5gb |
| `backups` | `backup` | worker built from `do/backup/` | apps-s-1vcpu-0.5gb |

Databases: `fleet-mysql` (MySQL 8.4, database and user `fleet`) and
`authentik-pg` (PostgreSQL 17, database and user `authentik`), both
db-s-1vcpu-1gb in nyc3, with daily backups and 7 days of point-in-time
restore. Each firewall admits the apps that use that database (`backups`
uses both), plus the Vultr VM until the cutover.

## Database setup notes

- **Creating an app for the first time:** Terraform learns an app's ID
  only after its first deploy finishes, but that deploy needs the database
  firewall to admit the app. As soon as the new app shows up in
  `doctl apps list` (or the API), add the same trusted sources Terraform
  will apply: the VM IP while it's listed, plus each app that uses the
  database (`PUT /v2/databases/<id>/firewall`). The 10-minute first-boot
  health check windows leave time for this. Terraform's later firewall
  update is then a no-op.

- **MySQL settings:** DigitalOcean may reset `sql_require_primary_key` and
  `sql_mode` when it creates a cluster. After creating one, run a plan; if
  `digitalocean_database_mysql_config` drifts, re-run the workflow
  (`workflow_dispatch`) to apply it again.
- **Postgres ownership:** `doadmin` owns new databases, and on Postgres 15+
  only the owner can create tables in `public`. After creating the
  database, as `doadmin`: `ALTER DATABASE authentik OWNER TO authentik;`
  (done 2026-11-18).
- **Restoring the Fleet dump:** strip the view's definer first. `doadmin`
  lacks SET_ANY_DEFINER:
  `sed -E 's#/\*!50013 DEFINER=`[^`]+`@`[^`]+` (SQL SECURITY [A-Z]+) \*/#/*!50013 \1 */#'`

## Terraform

`do/terraform/` is applied by `.github/workflows/do-terraform.yaml`: plan on
pull requests, apply on merge to `main`. State lives in the HCP Terraform
workspace `homelab-do` (org `kitzy_net`, Local execution mode).

Secrets come from the 1Password `GitHub` vault:

| Item | Used for |
| --- | --- |
| `Terraform Cloud` | HCP state access |
| `Cloudflare R2 Terraform` | R2 bucket management (Workers R2 Storage Read + Write only) |
| `DigitalOcean API Token` | DigitalOcean (team Homelab) |
| `homelab-do app secrets` | Fleet private key and license, Authentik secret key, restic password, Healthchecks URLs (copies of the Homelab vault values) |
| `R2 backups homelab-do` | Backup worker's S3 keys, scoped to `kitzy-homelab-backups` |

## R2 buckets

| Bucket | Holds |
| --- | --- |
| `kitzy-fleet-installers` | Fleet software installers, icons, bootstrap packages, org logos |
| `kitzy-homelab-backups` | restic repository for the nightly database dumps |

Both have `prevent_destroy`. Each bucket's object read/write token is created
outside Terraform, because creating tokens needs a permission that could mint
a token with any access. Those tokens live in 1Password.

S3 endpoint: `https://<account-id>.r2.cloudflarestorage.com`, region `auto`.
