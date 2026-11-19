# do/

DigitalOcean App Platform, a managed MySQL database, and Cloudflare R2 for
the homelab: Fleet (fleet.kitzy.net) and its backups. Everything here is
Terraform; nothing is changed by hand.
Migration plan and history: https://claude.ai/artifact/J9V68fpDaSEizhRfW4ZU7H

## Status

In production since the cutover on 2026-11-18 (`local.rehearsal = false` in
`terraform/app.tf`). The Vultr VM was decommissioned on 2026-11-19, and
Authentik on 2026-11-19: Fleet's SSO and IdP data now come straight from
Google Workspace (see `google/README.md`).

## Apps (region nyc)

Two App Platform apps, so each deploys, fails and rolls back on its own.

| App | Component | Kind | Size |
| --- | --- | --- | --- |
| `fleet` | `fleet` | service, port 8080 | apps-s-1vcpu-1gb-fixed |
| | `fleet-migrate` | PRE_DEPLOY job (`fleet prepare db`) | apps-s-1vcpu-0.5gb |
| | `redis` | internal service, port 6379 | apps-s-1vcpu-0.5gb |
| `backups` | `backup` | worker built from `do/backup/` | apps-s-1vcpu-0.5gb |

Database: `fleet-mysql` (MySQL 8.4, database and user `fleet`),
db-s-1vcpu-1gb in nyc3, with daily backups and 7 days of point-in-time
restore. Its firewall admits only the `fleet` and `backups` apps.

## Database setup notes

- **Creating an app for the first time:** Terraform learns an app's ID
  only after its first deploy finishes, but that deploy needs the database
  firewall to admit the app. As soon as the new app shows up in
  `doctl apps list` (or the API), add the same trusted sources Terraform
  will apply: each app that uses the database
  (`PUT /v2/databases/<id>/firewall`). The 10-minute first-boot health
  check windows leave time for this. Terraform's later firewall update is
  then a no-op.
- **MySQL settings:** DigitalOcean may reset `sql_require_primary_key` and
  `sql_mode` when it creates a cluster. After creating one, run a plan; if
  `digitalocean_database_mysql_config` drifts, re-run the workflow
  (`workflow_dispatch`) to apply it again.
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
| `homelab-do app secrets` | Fleet private key and license, restic password, Healthchecks URLs (copies of the Homelab vault values) |
| `R2 backups homelab-do` | Backup worker's S3 keys, scoped to `kitzy-homelab-backups` |
| `Fleet R2 homelab-do` | Fleet's S3 keys, scoped to `kitzy-fleet-installers` |

## R2 buckets

| Bucket | Holds |
| --- | --- |
| `kitzy-fleet-installers` | Fleet software installers, icons, bootstrap packages, org logos |
| `kitzy-homelab-backups` | restic repository for the nightly database dumps |

Both have `prevent_destroy`. Each bucket's object read/write token is created
outside Terraform, because creating tokens needs a permission that could mint
a token with any access. Those tokens live in 1Password.

S3 endpoint: `https://<account-id>.r2.cloudflarestorage.com`, region `auto`.

## Updates

Renovate opens a PR per image update (`renovate.json`): Fleet follows the
release-candidate channel, everything else stable releases. Merging the PR
applies it.

- **Fleet** migrates its database in the `fleet-migrate` pre-deploy job
  before the new version serves traffic.
- **Backup worker** (`do/backup/Dockerfile`): the workflow forces a rebuild
  when `do/backup/` changes; App Platform otherwise reuses the old build.

## Backups

| Layer | What | Restore with |
| --- | --- | --- |
| DigitalOcean managed backups | Daily, 7 days of point-in-time restore | DigitalOcean console or API: fork/restore to a point in time. Tested in Phase 3 (Fleet's table without a primary key restores fine). |
| restic to R2 | Nightly 23:00 ET: a dump of the Fleet database to `kitzy-homelab-backups`; 7 daily, 4 weekly, 3 monthly; `restic check` Sundays 21:00 ET; Healthchecks.io pings. Snapshots before 2026-11-19 also hold Authentik's database | Below |
| NAS archive (read-only) | The Vultr era's restic repository, `sftp:nas:/backups/homelab-vps`, including the cutover state as snapshot `8ac46124` (tag `cutover-final`) | restic with the `restic homelab-vps` 1Password item |

### Restoring from R2

1. Get the repository settings from 1Password: `homelab-do app secrets`
   (`RESTIC_PASSWORD`) and `R2 backups homelab-do` (S3 keys). Repository:
   `s3:https://<account-id>.r2.cloudflarestorage.com/kitzy-homelab-backups`,
   region `auto`.
2. `restic restore latest --host homelab-do --target <dir>` gives
   `dumps/fleet.sql`.
3. Load it as in the cutover: firewall the apps out (or take them down),
   end their sessions, reset the database, strip the view definer (see
   Database setup notes) and pipe it into `mysql` as user `fleet`,
   `--ssl-mode=VERIFY_IDENTITY`.
4. Redeploy the `fleet` app. A restore drill on 2026-11-18 matched every
   table.
