# homelab-vps

One Vultr VM runs Authentik and Fleet as Docker Compose stacks. [Doco-CD](https://doco.cd) on the VM polls this repo and deploys the stacks listed in [`.doco-cd.yml`](../.doco-cd.yml). This replaces the K3s, Flux, and Proxmox stack under [`kubernetes/`](../kubernetes/), which stays in the repo until the old data is decommissioned.

| Piece | Where |
| --- | --- |
| VM, firewall, tailnet key, cloud-init | [`terraform/`](terraform/), applied by [`vps-terraform.yaml`](../.github/workflows/vps-terraform.yaml) |
| Compose stacks | [`compose/`](../compose/) |
| Deploy config | [`.doco-cd.yml`](../.doco-cd.yml) |
| Public ingress | Cloudflare Tunnel `homelab-vps` (no inbound ports on the VM) |
| Admin access | Tailscale SSH to `homelab-vps` (`tag:vps`) |
| Secrets | 1Password, read by Doco-CD with a service account |
| Backups | restic over SFTP to the Synology |

## The VM

- Vultr High Performance, plan `vhp-4c-8gb-amd` (4 vCPU, 8 GB, 180 GB NVMe), region `ewr` (New Jersey), Ubuntu 24.04. About $48 a month.
- Firewall group with no inbound rules. Everything the VM does is outbound: Tailscale, the Cloudflare Tunnel, Doco-CD polling GitHub, restic to the NAS.
- Cloud-init installs Docker (with log rotation) and Tailscale, adds a 4 GB swap file, enables unattended security upgrades, joins the tailnet as `homelab-vps` with `tag:vps`, creates the `proxy` Docker network, and writes `/opt/doco-cd/compose.yaml`. It does not start Doco-CD.
- `prevent_destroy` is set on the instance. Every Docker volume, so every database, lives on the VM disk. A replace would destroy them. Terraform also ignores changes to `user_data` and `os_id`, so editing cloud-init never forces a replace. Cloud-init changes only apply to a newly built VM.
- Optional, off by default: Vultr automatic backups (`enable_vultr_backups`) and a block storage volume for `/var/lib/docker` (`docker_volume_size_gb`). The volume only takes effect when the VM is first created.

## One-time setup

### 1. HCP Terraform workspace

1. In [HCP Terraform](https://app.terraform.io/), organization `kitzy_net`, create a workspace named `homelab-vps`.
2. Choose the CLI-driven workflow. No VCS connection.
3. In Settings, General, set Execution Mode to Local. GitHub Actions runs Terraform. HCP only stores and locks state.

The existing `Terraform Cloud` item in the 1Password `GitHub` vault already holds an org token that CI uses.

### 2. Vultr API key

1. In the Vultr portal, Account, API, enable the API and copy the key.
2. Store it in the 1Password `GitHub` vault as an API Credential item named `Vultr API Key`, with the key in the `credential` field. The workflow reads `op://GitHub/Vultr API Key/credential`. It must be in the `GitHub` vault, the only vault the GitHub Actions service account can read.
3. Access control: Vultr API keys have an IP allowlist. GitHub-hosted runners use changing IPs, so the allowlist has to allow any IPv4 (`0.0.0.0/0`) and IPv6 (`::/0`).

> **Risk:** with an open allowlist, anyone who gets the key can manage the whole Vultr account, including deleting the VM. The key lives only in 1Password and in masked CI env vars. Rotate it if it leaks. The fix is a self-hosted runner with a fixed IP (for example on the VM itself, over Tailscale), which is not set up.

### 3. Tailscale

- PR 1 added `tag:vps` to [`tailscale/policy.hujson`](../tailscale/policy.hujson). That must be applied before this Terraform runs, or the tagged key cannot be minted.
- Terraform uses the same OAuth client as the `tailscale/` root (`Tailscale ACL` in the `GitHub` vault). Its scope is `all`, which includes `auth_keys` write. If the client is ever narrowed, it needs `auth_keys` write and must own `tag:vps`.

### 4. Apply

Merging a change under `vps/terraform/` to `main` runs `terraform apply`. The first apply creates the VM. Within a few minutes `homelab-vps` appears on the tailnet, tagged `tag:vps`.

Check:

```bash
tailscale status | grep homelab-vps
```

```bash
ssh root@homelab-vps 'cloud-init status --long; docker version --format "{{.Server.Version}}"; swapon --show; docker network ls | grep proxy'
```

To confirm no public ports are open, scan the public IP (Terraform output `public_ipv4`) from outside the tailnet. Every port should be filtered.

## Bootstrap Doco-CD

Doco-CD cannot deploy itself, so it runs from `/opt/doco-cd/compose.yaml`, written by cloud-init. The repo is public, so it needs no GitHub token. It needs one secret: a 1Password service account token.

### 1Password service account

1. In 1Password, Developer, Service Accounts, create `doco-cd-homelab-vps` with **read-only** access to the `Homelab` vault only. Service accounts cannot read Personal vaults.
2. Write the token to the VM. Run this on your Mac. It never echoes the token or puts it in shell history:

    ```bash
    op read "op://<vault>/<service account item>/credential" | ssh root@homelab-vps 'umask 077; cat > /opt/doco-cd/op_token'
    ```

    Or paste it with `ssh root@homelab-vps` then `umask 077; cat > /opt/doco-cd/op_token` and Ctrl-D.
3. Start Doco-CD:

    ```bash
    ssh root@homelab-vps 'cd /opt/doco-cd && docker compose up -d && docker compose logs --tail 50'
    ```

Doco-CD polls `main` every 3 minutes and deploys every stack in `.doco-cd.yml`.

### Upgrading Doco-CD

Edit the image tag in `/opt/doco-cd/compose.yaml` on the VM, then `docker compose up -d`. Keep [`terraform/cloud-init.yaml.tftpl`](terraform/cloud-init.yaml.tftpl) in sync so a rebuilt VM gets the same version.

## Stacks

Each stack is a directory under [`compose/`](../compose/) and one document in [`.doco-cd.yml`](../.doco-cd.yml).

| Stack | Services | Public via |
| --- | --- | --- |
| `edge` | `cloudflared` | (it is the tunnel) |
| `authentik` | `authentik-db`, `authentik-media-perms` (one-shot), `authentik-server`, `authentik-worker` | `auth.kitzy.net` → `http://authentik-server:9000` |
| `fleet` | `fleet-mysql`, `fleet-redis`, `fleet-volume-perms` (one-shot), `fleet-migrate` (one-shot), `fleet` | `fleet.kitzy.net` → `http://fleet:8080` |

Conventions:

- Every image tag is pinned. Renovate covers `compose/*/compose.yaml` (see [`renovate.json`](../renovate.json)). It keeps MySQL on 8.0, Postgres on 17, and Redis on 7.
- Named volumes only, with fixed names (`fleet_mysql`, `authentik_pgdata`, ...). No bind mounts from the repo: Doco-CD runs in a container, so a relative path would resolve somewhere the Docker daemon cannot see. Config files use `configs` with inline `content`.
- `proxy` is an external network created by cloud-init. Only cloudflared and the apps' HTTP services join it. Databases stay on each stack's own network (`authentik-backend`, `fleet-backend`), which have fixed names so the backup stack can join them.
- Healthchecks on every long-running service. `depends_on` waits for `service_healthy`, or `service_completed_successfully` for one-shots.
- `restart: unless-stopped`. Log rotation comes from `daemon.json`.
- `mem_limit` on every service as a safety net:

  | Service | Limit |
  | --- | --- |
  | authentik-server | 3 GB |
  | authentik-worker | 768 MB |
  | authentik-db | 512 MB |
  | fleet | 2 GB |
  | fleet-mysql | 2 GB (buffer pool 1 GB) |
  | fleet-redis | 256 MB |
  | cloudflared | 192 MB |
  | doco-cd | 256 MB (the 1Password provider raises its memory use) |

  Check `docker stats` in the first week. If use stays above about 6.5 GB, move to the 16 GB plan (about $81 a month) by changing `plan` in [`terraform/variables.tf`](terraform/variables.tf). A plan resize is an in-place change on Vultr. Read the Terraform plan before merging to make sure it says update, not replace.

### Profiles: staged first deploy

Services without a profile always run. Everything except the databases (and cloudflared) is in the `app` profile. `.doco-cd.yml` starts with `profiles: []`, so the first deploy brings up only the databases. Restore the old dumps into them, then a follow-up PR sets `profiles: [app]`. Restoring before the apps start matters: an app that boots first runs its migrations on an empty database, and the restore then collides with them.

### 1Password items

Doco-CD reads these from the `Homelab` vault. The 1Password provider has no bulk fetch, so every field is listed in `.doco-cd.yml`. A deploy fails if any reference is missing, even for services in an inactive profile, so all of these must exist before the first deploy.

| Item | Fields | Status |
| --- | --- | --- |
| `authentik-secrets` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_HOST`, `AUTHENTIK_COOKIE_DOMAIN` | exists |
| `Fleet Secrets` | `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `FLEET_SERVER_PRIVATE_KEY`, `FLEET_LICENSE_KEY`, `FLEET_S3_SOFTWARE_INSTALLERS_BUCKET`, `FLEET_S3_SOFTWARE_INSTALLERS_ACCESS_KEY_ID`, `FLEET_S3_SOFTWARE_INSTALLERS_SECRET_ACCESS_KEY` | exists |
| `Cloudflare Tunnel` | `VPS_TUNNEL_TOKEN` (new field, token of the new `homelab-vps` tunnel; the old `TUNNEL_TOKEN` stays for rollback) | **create** |

To create the tunnel token: in Cloudflare Zero Trust, Networks, Tunnels, create a Cloudflared tunnel named `homelab-vps`. Copy its token into a new `VPS_TUNNEL_TOKEN` field on `Cloudflare Tunnel`, and note the tunnel ID for the DNS PR. Do not add public hostnames in the dashboard. The `dns/` Terraform manages them.

## Backups

The `backup` stack ([`compose/backup/compose.yaml`](../compose/backup/compose.yaml)) runs nightly jobs through Doco-CD's built-in scheduler (`cd.doco.job.*` labels). No host cron is used. Times are America/New_York.

| Time | Job | What it does |
| --- | --- | --- |
| 02:00 | `dump-fleet` | `mysqldump` (Oracle client, `mysql:8.0.46`) of `fleet`. Fails and deletes the dump unless it has at least 100 tables and includes `users`, `migration_status_tables`, and `hosts`. |
| 02:10 | `dump-authentik` | `pg_dump` 17, plain format. Fails unless the dump has pg_dump's completion footer. |
| 03:00 | `restic-backup` | Fails if any dump is missing or more than 3 hours old. Otherwise it snapshots `backup_dumps` and the `authentik_media` volume, then runs `forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune`. |
| Sun 05:00 | `restic-check` | `restic check`. |

The restic jobs ping Healthchecks.io on start, success, and failure. A dump job that fails leaves the previous dump in place, so the restic job sees a stale file and pings `/fail`. If Doco-CD or the VM is down, nothing pings, and Healthchecks.io alerts on the missed schedule.

This fixes two gaps in the K8s setup: Authentik dumps are now pruned (retention applies to every snapshot), and the Authentik media volume is backed up. The Fleet vulndb is not backed up, because Fleet rebuilds it.

Repository: `sftp:restic@10.253.20.10:/backups/homelab-vps`, reached over the Tailscale subnet route (`tag:vps` may reach only `10.253.20.10:22`). The NAS host key is pinned in the compose file.

`BACKUP_JOBS_ENABLED` in `.doco-cd.yml` gates the schedules. It stays `"false"` until the steps below are done.

### Setup

1. **NAS user.** [`nas-restic-setup.sh`](nas-restic-setup.sh) creates the `restic` user (key auth only), a `backups` shared folder on `/volume2` (read/write for `restic` and administrators), `backups/homelab-vps`, `~restic/.ssh/authorized_keys` with the restic public key, and turns on SFTP (it was off). It needs root, so run it with your sudo password:

    ```bash
    ssh admin@10.253.20.10 'cat > /tmp/nas-restic-setup.sh' < vps/nas-restic-setup.sh
    ```

    ```bash
    ssh -t admin@10.253.20.10 'sudo sh /tmp/nas-restic-setup.sh; rm -f /tmp/nas-restic-setup.sh'
    ```

    (`scp` does not work until SFTP is on.) Afterwards, in DSM, check that `restic` has no access to any other shared folder. DSM chroots SFTP users to the shared-folder root, so the repository path is `/backups/homelab-vps`.
2. **Key and password.** On your Mac, generate the SSH key and the restic password, and store them in 1Password (`Homelab` vault, item `restic homelab-vps`). The private key is stored base64-encoded on one line, so it survives being an env var:

    ```bash
    d=$(mktemp -d) && ssh-keygen -q -t ed25519 -N "" -C restic@homelab-vps -f "$d/id" && op item create --vault Homelab --category password --title "restic homelab-vps" --generate-password='letters,digits,32' "ssh_private_key_b64[concealed]=$(base64 < "$d/id" | tr -d '\n')" "ssh_public_key[text]=$(cat "$d/id.pub")" >/dev/null && cat "$d/id.pub" && rm -rf "$d"
    ```

    The item `restic homelab-vps` already exists (created 2026-11-17). Its public key is the one in `nas-restic-setup.sh`. If you ever regenerate the key, update the script and re-run it.
3. **Healthchecks.io.** Create two checks: `homelab-vps backup` (daily, 03:00 America/New_York, grace 2 hours) and `homelab-vps restic check` (weekly, Sunday 05:00, grace 6 hours). Store their ping URLs in a `Homelab` item `Healthchecks homelab-vps`, fields `backup_ping_url` and `check_ping_url`.
4. **Run each job once by hand** after the databases are restored and the backup stack has deployed. The first `restic-backup` run creates the repository (it initializes only when restic reports that no repository exists, never on a connection or auth error):

    ```bash
    ssh root@homelab-vps 'for j in dump-fleet dump-authentik restic-backup restic-check; do echo "== $j"; docker start -a backup-$j-1 || break; done'
    ```

    The job scripts live in each container's `command`, so `docker start -a` runs exactly what the scheduler runs. Container names follow Compose's `<project>-<service>-1`. List them with `docker ps -a --filter label=com.docker.compose.project=backup`.
5. Set `BACKUP_JOBS_ENABLED: "true"` in `.doco-cd.yml` and merge. Check the next morning that both Healthchecks.io checks are green.

### Ad-hoc restic commands

[`restic-adhoc.sh`](restic-adhoc.sh) runs any restic command against the repository. It reads the settings and key from the stopped `restic-backup` job container, so nothing secret stays on the host:

```bash
ssh root@homelab-vps 'bash -s -- snapshots' < vps/restic-adhoc.sh
```

### Restore drill

Restore the latest snapshot to `/root/restore-drill` and compare it with the live data:

```bash
ssh root@homelab-vps 'bash -s -- restore latest --target /restore' < vps/restic-adhoc.sh
```

Then load `/root/restore-drill/dumps/*.sql` into throwaway database containers and spot-check them (for Fleet, the table count and `SELECT COUNT(*) FROM hosts`). Delete `/root/restore-drill` afterwards.

### Later hardening

Run `rest-server --append-only` on the NAS (Container Manager) and point restic at it. A compromised VM then cannot delete backups. Pruning moves to a trusted job on the NAS.

## Security notes

- Doco-CD mounts the Docker socket, which is root-equivalent on the VM. The 1Password token also lives on the VM. Keep the service account scoped to one vault, read-only.
- The Tailscale bootstrap key is in the instance `user_data`, which the Vultr metadata service serves to anything on the VM. It is single-use and expires an hour after it is minted, so it is spent by the time anything else runs.
- No public inbound ports. Admin access is Tailscale SSH only (check mode).
- Rotate the 1Password service account token and the Vultr API key if the VM is rebuilt or suspected compromised.
