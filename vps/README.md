# homelab-vps

One Vultr VM runs Authentik and Fleet as Docker Compose stacks. [Doco-CD](https://doco.cd) on the VM polls this repo and deploys the stacks listed in [`.doco-cd.yml`](../.doco-cd.yml). This replaced the K3s, Flux, and Proxmox stack in November 2026. Its manifests (`kubernetes/`) are in the git history; the old data stays on the Synology until it is decommissioned.

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
- Firewall group that allows only UDP 41641 inbound (Tailscale direct connections). A Vultr firewall group with no rules allows everything, so that one rule is what makes it drop the rest. `sshd` is disabled; admin access is Tailscale SSH. Everything else the VM does is outbound: the Cloudflare Tunnel, Doco-CD polling GitHub, restic to the NAS.
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

To confirm no public ports are open, scan the public IP (Terraform output `public_ipv4`) from outside the tailnet. Every TCP port should be filtered.

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
  | doco-cd | 512 MB (measured ~210 MB while deploying; the 1Password provider raises its memory use) |

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

## Migration runbook: restore from the K3s cluster

The K3s cluster is down, so fresh dumps are impossible. The data comes from the last nightly dumps the old CronJobs wrote to the NFS share. At most you lose about a day of changes. The old iSCSI volumes stay untouched on the Synology until the new stack is proven.

Container names below follow Compose's `<project>-<service>-1` (for example `fleet-fleet-mysql-1`). Commands run from your Mac unless noted. Scanopy is not migrating; its old dumps stay on the NAS.

### 0. Before you start

- [ ] #180 to #183 merged. The VM exists, Doco-CD is running, and phase 1 is deployed: `ssh root@homelab-vps 'docker ps --format "{{.Names}} {{.Status}}"'` shows `authentik-authentik-db-1`, `fleet-fleet-mysql-1`, `fleet-fleet-redis-1`, and `edge-cloudflared-1`, all healthy.
- [ ] The new 1Password field `Cloudflare Tunnel/VPS_TUNNEL_TOKEN` exists. See [1Password items](#1password-items).
- [ ] The tunnel `homelab-vps` shows as healthy in Cloudflare Zero Trust. It has no routes yet.

### 1. Protect the old data

In DSM, Storage Manager (SAN Manager on DSM 7), take a manual snapshot of every K3s iSCSI LUN before touching anything. Do not delete or modify the LUNs or `/volume2/k8s-backups` until the restore drill in step 10 passes.

### 2. Find the latest dumps

```bash
ssh admin@10.253.20.10 'for d in fleet authentik; do echo "== $d"; ls -lt /volume2/k8s-backups/$d | head -4; done'
```

Note the newest file for each app and its date. They should all be from the last night the cluster ran. If one is older than the others, note how much data it loses before deciding to go ahead.

Checked on 2026-11-17: the newest dumps are `fleet-20261113-020000.sql.gz` and `authentik-20261113-030000.sql.gz`, both from the cluster's last night. Both were restored into these exact stacks in a local test: Fleet had 17 hosts and migrated forward cleanly; Authentik had 8 users and needed no migrations. Both apps came up healthy.

The link to the NAS runs over the home uplink and one test transfer was cut off partway. That is why the dumps go to a file first and get `gzip -t` before anything is restored. If a check fails, copy that dump again.

Stream them to the VM (nothing lands on your Mac):

```bash
ssh root@homelab-vps 'install -d -m 700 /root/restore'
```

```bash
for d in fleet authentik; do f=$(ssh admin@10.253.20.10 "ls -t /volume2/k8s-backups/$d/*.sql.gz | head -1"); echo "$f"; ssh admin@10.253.20.10 "cat '$f'" | ssh root@homelab-vps "cat > /root/restore/$d.sql.gz"; done
```

```bash
ssh root@homelab-vps 'cd /root/restore && ls -l && for f in *.sql.gz; do gzip -t "$f" && echo "$f: gzip OK"; done'
```

### 3. Test each dump before relying on it

Load each dump into a throwaway container on the VM. Nothing here touches the real volumes.

Fleet. Expect 100+ tables and a host count that matches what you remember:

```bash
ssh root@homelab-vps 'set -eo pipefail
trap "docker rm -f fleet-scratch >/dev/null 2>&1" EXIT
docker run -d --rm --name fleet-scratch -e MYSQL_ROOT_PASSWORD=scratch -e MYSQL_DATABASE=fleet mysql:8.0.46 >/dev/null
until docker exec fleet-scratch mysqladmin ping -h 127.0.0.1 --silent 2>/dev/null; do sleep 3; done
gzip -dc /root/restore/fleet.sql.gz | docker exec -i -e MYSQL_PWD=scratch fleet-scratch mysql -uroot fleet
docker exec -e MYSQL_PWD=scratch fleet-scratch mysql -uroot -N fleet -e "SELECT COUNT(*) AS tables FROM information_schema.tables WHERE table_schema=\"fleet\"; SELECT COUNT(*) AS hosts FROM hosts; SELECT MAX(version_id) FROM migration_status_tables;"'
```

Authentik. It should load with no errors. The scratch database first gets the owner roles the dump refers to, so ownership statements succeed:

```bash
ssh root@homelab-vps 'set -eo pipefail
trap "docker rm -f authentik-scratch >/dev/null 2>&1" EXIT
for d in authentik; do
  docker run -d --rm --name $d-scratch -e POSTGRES_PASSWORD=scratch -e POSTGRES_DB=$d postgres:17.12-alpine >/dev/null
  until docker exec $d-scratch pg_isready -U postgres -d $d >/dev/null 2>&1; do sleep 2; done; sleep 2
  for r in $(gzip -dc /root/restore/$d.sql.gz | grep -oE "OWNER TO [A-Za-z0-9_]+" | cut -d" " -f3 | sort -u); do
    docker exec $d-scratch psql -q -U postgres -c "CREATE ROLE \"$r\"" 2>/dev/null || true
  done
  gzip -dc /root/restore/$d.sql.gz | docker exec -i $d-scratch psql -q -v ON_ERROR_STOP=1 -U postgres -d $d >/dev/null
  echo "$d tables: $(docker exec $d-scratch psql -tA -U postgres -d $d -c "select count(*) from information_schema.tables where table_schema=current_schema()")"
  docker stop $d-scratch >/dev/null
done'
```

### 4. Phase 1 must be databases only

Confirm none of the apps ever started. If an app booted against an empty database, it ran its migrations, and the restore would collide:

```bash
ssh root@homelab-vps 'docker ps -a --format "{{.Names}}" | grep -E "authentik-server|authentik-worker|fleet-fleet-1|fleet-migrate" || echo "no app containers: good"'
```

If any exist, stop them, then drop and recreate that database before restoring.

### 5. Restore

Each restore goes into the empty database that the image created on first start, using the credentials already in the container's env.

Fleet. The dumps were taken without `--databases`, so they load into the existing `fleet` database:

```bash
ssh root@homelab-vps 'set -o pipefail; gzip -dc /root/restore/fleet.sql.gz | docker exec -i fleet-fleet-mysql-1 sh -c "MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysql -uroot fleet" && docker exec fleet-fleet-mysql-1 sh -c "MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysql -uroot -N fleet -e \"SELECT COUNT(*) FROM hosts\""'
```

Authentik:

```bash
ssh root@homelab-vps 'set -o pipefail; gzip -dc /root/restore/authentik.sql.gz | docker exec -i authentik-authentik-db-1 sh -c "psql -q -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\"" >/dev/null && echo authentik restored'
```

If a restore fails partway, do not retry on top of it. Drop and recreate the database (`DROP DATABASE ...; CREATE DATABASE ...;` as the superuser), then run it again.

### 6. Authentik media (optional)

The media volume (1 GiB: custom icons and branding) was on iSCSI LUN `pvc-3f1d6c20-3384-4a6c-926a-104f26496c44` and was never backed up. To recover it, clone the LUN snapshot from step 1 in DSM, attach the clone read-only to a Linux host on the LAN (for example `homelab-01` with `open-iscsi`), mount it, and stream it into the new volume:

```bash
ssh homelab-01 'sudo tar -C /mnt/authentik-media -c .' | ssh root@homelab-vps 'docker run -i --rm -v authentik_media:/media busybox:1.37.0 tar -x -C /media'
```

If that is not worth the effort, skip it and re-upload icons and branding in the Authentik admin UI. `authentik-media-perms` fixes ownership when the app profile starts.

### 7. Phase 2: start the apps

Merge the PR that sets `profiles: [app]` on `authentik` and `fleet` in `.doco-cd.yml`.

Watch it come up (Authentik may take a few minutes if it runs migrations):

```bash
ssh root@homelab-vps 'docker logs doco-cd --since 10m 2>&1 | tail -30; docker ps --format "{{.Names}}\t{{.Status}}"'
```

```bash
ssh root@homelab-vps 'docker logs fleet-fleet-migrate-1 2>&1 | tail -5'
```

The Nov 13 Fleet dump is from before v4.95.0, so `fleet prepare db` applies about 24 migrations (seen in the local test). If Fleet then crash-loops with `decrypting mdm config asset ... message authentication failed`, `FLEET_SERVER_PRIVATE_KEY` does not match the one the data was encrypted with. The key in 1Password was confirmed to work against this dump.

### 8. Smoke test before DNS

The apps are not published on host ports. Test them from the VM against their container IPs on the `proxy` network:

```bash
ssh root@homelab-vps 'ip(){ docker inspect -f "{{(index .NetworkSettings.Networks \"proxy\").IPAddress}}" "$1"; }
curl -fsS "http://$(ip fleet-fleet-1):8080/healthz" && echo " fleet healthz OK"
curl -fsS -o /dev/null -w "authentik live: %{http_code}\n" "http://$(ip authentik-authentik-server-1):9000/-/health/live/"'
```

For a browser check, forward a port over Tailscale SSH. Find the IP with the `ip` helper above, then:

```bash
ssh -L 9000:<authentik-server-ip>:9000 root@homelab-vps
```

Then open `http://localhost:9000` and log in. Full SSO flows depend on the real hostname, so they are tested after cutover.

### 9. DNS cutover

Merge the DNS PR. It points `auth` and `fleet` at the `homelab-vps` tunnel and removes `hello`. Cloudflare TTL is 300 seconds. Then verify:

- A Fleet host checks in (Fleet UI, Hosts, last seen updates). Agents enroll through `fleet.kitzy.net`, which does not change.
- Log in to `https://auth.kitzy.net`.
- One SSO flow into an app that uses Authentik.
- External uptime monitors on `https://fleet.kitzy.net/healthz` and `https://auth.kitzy.net/-/health/live/` (free tier of any uptime service).

### 10. Turn on backups and run a restore drill

Follow [Backups, Setup](#setup). Then run one full restore drill ([Restore drill](#restore-drill)) and compare it with the live data. After it passes, delete `/root/restore` on the VM (the old dumps).

### Rollback

The old cluster is fully retired: its manifests are only in git history, and its Cloudflare tunnel (`homelab-k3s`), Tailscale devices, and credentials were deleted on 2026-11-17. There is no quick rollback. The old iSCSI LUNs and nightly dumps are still on the Synology until they are decommissioned.

## Security notes

- Doco-CD mounts the Docker socket, which is root-equivalent on the VM. The 1Password token also lives on the VM. Keep the service account scoped to one vault, read-only.
- The Tailscale bootstrap key is in the instance `user_data`, which the Vultr metadata service serves to anything on the VM. It is single-use and expires an hour after it is minted, so it is spent by the time anything else runs.
- No public inbound ports. Admin access is Tailscale SSH only (check mode).
- Rotate the 1Password service account token and the Vultr API key if the VM is rebuilt or suspected compromised.
