# homelab-vps

One Vultr VM runs Authentik and Fleet as Docker Compose stacks. [Doco-CD](https://doco.cd) on the VM polls this repo and deploys the stacks listed in [`.doco-cd.yml`](../.doco-cd.yml). It replaced the K3s, Flux, and Proxmox setup in November 2026 (see [Migration history](#migration-history)).

| Piece | Where |
| --- | --- |
| VM, firewall, tailnet key, cloud-init | [`terraform/`](terraform/), applied by [`vps-terraform.yaml`](../.github/workflows/vps-terraform.yaml) |
| Compose stacks | [`compose/`](../compose/) |
| Deploy config | [`.doco-cd.yml`](../.doco-cd.yml) |
| Public ingress | Cloudflare Tunnel `homelab-vps` → `auth.kitzy.net`, `fleet.kitzy.net` (no inbound TCP ports on the VM) |
| Admin access | Tailscale SSH to `homelab-vps` (`tag:vps`, check mode) |
| Secrets | 1Password `Homelab` vault, read by Doco-CD with a read-only service account |
| Backups | restic over SFTP to the Synology, nightly, monitored by Healthchecks.io |
| Device management | The VM itself is enrolled in Fleet (fleetd, scripts enabled) |

## The VM

- Vultr High Performance, plan `vhp-4c-8gb-amd` (4 vCPU, 8 GB, 180 GB NVMe), region `ewr` (New Jersey), Ubuntu 24.04. About $48 a month. Public IP `45.77.154.196`, tailnet name `homelab-vps`.
- The firewall group allows only UDP 41641 inbound (Tailscale direct connections). A Vultr firewall group with **no** rules allows everything, so that one rule is what makes it drop the rest. `sshd` is disabled; admin access is Tailscale SSH. Everything else is outbound: the Cloudflare Tunnel, Doco-CD polling GitHub, restic to the NAS, Fleet's agent.
- Cloud-init installs Docker (with log rotation) and Tailscale, makes sure swap exists, enables unattended security upgrades (no automatic reboots), turns off `sshd`, joins the tailnet as `homelab-vps` with `tag:vps`, creates the `proxy` Docker network, and writes `/opt/doco-cd/compose.yaml`. It does not start Doco-CD. Vultr's Ubuntu image already ships an 8 GB `/swapfile`, so that is what the VM has.
- `prevent_destroy` is set on the instance. Every Docker volume, so every database, lives on the VM disk, and a replace would destroy them. Terraform also ignores changes to `user_data` and `os_id`, so editing cloud-init never forces a replace. Cloud-init changes only apply to a newly built VM.
- Optional, off by default: Vultr automatic backups (`enable_vultr_backups`) and a block storage volume for `/var/lib/docker` (`docker_volume_size_gb`, only takes effect when the VM is first created).
- Memory: about 3.2 GB of 7.7 GB in use with everything running (2026-11-17), swap untouched. If `docker stats` shows sustained use above about 6.5 GB, move to the 16 GB plan (about $81 a month) by changing `plan` in [`terraform/variables.tf`](terraform/variables.tf). A plan resize is an in-place change on Vultr. Read the Terraform plan before merging to make sure it says update, not replace.

## Stacks

Each stack is a directory under [`compose/`](../compose/) and one document in [`.doco-cd.yml`](../.doco-cd.yml). Doco-CD polls `main` every 3 minutes and runs `docker compose up` for stacks whose files changed.

| Stack | Services | Public via |
| --- | --- | --- |
| `edge` | `cloudflared` | (it is the tunnel) |
| `authentik` | `authentik-db`, `authentik-media-perms` (one-shot), `authentik-server`, `authentik-worker` | `auth.kitzy.net` → `http://authentik-server:9000` |
| `fleet` | `fleet-mysql`, `fleet-redis`, `fleet-volume-perms` (one-shot), `fleet-migrate` (one-shot), `fleet` | `fleet.kitzy.net` → `http://fleet:8080` |
| `backup` | scheduled jobs: `dump-fleet`, `dump-authentik`, `restic-backup`, `restic-check` | none |

Hostname → service routing lives in [`dns/dns_zones/kitzy.net.yml`](../dns/dns_zones/kitzy.net.yml) (`TUNNEL` records), not in the stacks.

Conventions:

- Every image tag is pinned. Renovate opens update PRs (see [Updates](#updates)).
- Named volumes only, with fixed names (`fleet_mysql`, `authentik_pgdata`, `authentik_media`, ...). No bind mounts from the repo: Doco-CD runs in a container, so a relative path would resolve somewhere the Docker daemon cannot see. Config files use `configs` with inline `content`.
- `proxy` is an external network created by cloud-init. Only cloudflared and the apps' HTTP services join it. Databases stay on each stack's own network (`authentik-backend`, `fleet-backend`), which have fixed names so the backup stack can join them.
- Healthchecks on every long-running service. `depends_on` waits for `service_healthy`, or `service_completed_successfully` for one-shots.
- `restart: unless-stopped`. Log rotation comes from `daemon.json` (10 MB × 3 per container).
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
  | backup jobs | 512 MB each |
  | doco-cd | 512 MB (it used ~210 MB during the first deploy; the 1Password provider raises its memory use) |

### Profiles

Everything except the databases and cloudflared is in the `app` profile, and `.doco-cd.yml` runs every stack with `profiles: [app]`. Setting `profiles: []` instead brings up only the databases. That is how a restore works (see [Disaster recovery](#disaster-recovery)): an app that boots against an empty database runs its migrations, and a restore on top of that collides with them.

### 1Password items

Doco-CD reads these from the `Homelab` vault. The 1Password provider has no bulk fetch, so every field is listed in `.doco-cd.yml`. A deploy fails if any reference is missing, even for services in an inactive profile.

| Item | Fields | Used by |
| --- | --- | --- |
| `authentik-secrets` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_HOST`, `AUTHENTIK_COOKIE_DOMAIN` | `authentik`, `backup` |
| `Fleet Secrets` | `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `FLEET_SERVER_PRIVATE_KEY`, `FLEET_LICENSE_KEY`, `FLEET_S3_SOFTWARE_INSTALLERS_BUCKET`, `FLEET_S3_SOFTWARE_INSTALLERS_ACCESS_KEY_ID`, `FLEET_S3_SOFTWARE_INSTALLERS_SECRET_ACCESS_KEY` | `fleet`, `backup` |
| `Cloudflare Tunnel` | `VPS_TUNNEL_TOKEN` (token of tunnel `homelab-vps`, ID `0b72a860-709f-40ba-816c-7727f12e100f`) | `edge` |
| `restic homelab-vps` | `password`, `ssh_private_key_b64` (base64 on one line), `ssh_public_key` | `backup` |
| `Healthchecks homelab-vps` | `backup_ping_url`, `check_ping_url` | `backup` |

Two more items are not read by Doco-CD:

- `Doco-CD service account (homelab-vps)`: the token in `/opt/doco-cd/op_token` on the VM. Its title has parentheses, which `op://` references cannot contain, so read it by item ID.
- `Authentik Secrets` (capitalized): an older copy of the live `POSTGRES_PASSWORD` and `AUTHENTIK_SECRET_KEY`. Keep it as a backup of the secret key, which cannot be regenerated.

## Updates

Renovate opens a PR for every image in `compose/*/compose.yaml` (see [`renovate.json`](../renovate.json)). Automerge is off. Merging to `main` deploys within about 3 minutes.

- **Everything except Fleet:** stable releases only. MySQL stays on 8.0, Postgres on 17, and Redis on 7, because their major upgrades need a planned migration.
- **Fleet:** follows release candidates (the newest of stable and RC). RCs run one-way database migrations. Merging one means the only way back is the last nightly restic snapshot. A stable release supersedes its own RC. Image digests are pinned because RC tags are rebuilt in place.
- **Fleet upgrades** run `fleet prepare db --no-prompt` in the one-shot `fleet-migrate` before `fleet` starts. `fleet serve` refuses to start while migrations are pending, so that service is required. Bump the tag in both places in `compose/fleet/compose.yaml`.
- **Authentik upgrades must go one release line at a time.** Authentik treats each release line (`2025.10`, `2025.12`, `2026.2`, ...) as a major version and refuses to start if one is skipped (`Major version skips are not allowed`). The check runs before any migration, so a skipped upgrade only crash-loops the server: nothing is lost, and the fix is to go back to the previous tag. Upgrade to the newest patch of each line in order, and let each one finish its migrations before the next. Check the [upgrade notes](https://docs.goauthentik.io/install-config/upgrade/) for each line. Renovate opens one PR per release line within a year (merge the oldest first). A change of year (`2026.x` → `2027.x`) waits for approval on Renovate's Dependency Dashboard, because Renovate would otherwise offer the new year's newest line in one jump.
- **Doco-CD** is not managed by Renovate. Edit the image tag in `/opt/doco-cd/compose.yaml` on the VM, then `docker compose up -d`. Keep [`terraform/cloud-init.yaml.tftpl`](terraform/cloud-init.yaml.tftpl) in sync so a rebuilt VM gets the same version.

## Backups

The `backup` stack ([`compose/backup/compose.yaml`](../compose/backup/compose.yaml)) runs nightly jobs through Doco-CD's built-in scheduler (`cd.doco.job.*` labels). No host cron is used. Times are America/New_York.

| Time | Job | What it does |
| --- | --- | --- |
| 02:00 | `dump-fleet` | `mysqldump` (Oracle client, `mysql:8.0.46`) of `fleet`. Fails and deletes the dump unless it has at least 100 tables and includes `users`, `migration_status_tables`, and `hosts`. |
| 02:10 | `dump-authentik` | `pg_dump` 17, plain format. Fails unless the dump has pg_dump's completion footer. |
| 03:00 | `restic-backup` | Fails if any dump is missing or more than 3 hours old. Otherwise it snapshots `backup_dumps` and the `authentik_media` volume, then runs `forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune`. On its very first run it creates the repository (only when restic reports that none exists, never on a connection or auth error). |
| Sun 05:00 | `restic-check` | `restic check`. |

- Repository: `sftp:restic@10.253.20.10:/backups/homelab-vps`, over the Tailscale subnet route. `tag:vps` may reach only `10.253.20.10:22`. The NAS host key is pinned in the compose file.
- Healthchecks.io checks `backup_ping` (daily) and `check_ping` (weekly) get a ping on start, success, and failure. A failed dump leaves the previous dump in place, so the restic job sees a stale file and pings `/fail`. If Doco-CD or the VM is down, nothing pings, and Healthchecks.io alerts on the missed schedule.
- `BACKUP_JOBS_ENABLED` in `.doco-cd.yml` gates the schedules. It is `"true"`.
- The Fleet vulndb is not backed up, because Fleet rebuilds it.
- First verified 2026-11-17: snapshot of 421 MiB (53 MiB stored), `restic check` clean, and a restore drill matched both dumps byte for byte.

### Running jobs by hand

The job scripts live in each container's `command`, so `docker start -a` runs exactly what the scheduler runs:

```bash
ssh root@homelab-vps 'for j in dump-fleet dump-authentik restic-backup restic-check; do echo "== $j"; docker start -a backup-$j-1 || break; done'
```

### Ad-hoc restic commands and restore drills

[`restic-adhoc.sh`](restic-adhoc.sh) runs any restic command against the repository. It reads the settings and key from the stopped `restic-backup` job container, so nothing secret stays on the host:

```bash
ssh root@homelab-vps 'bash -s -- snapshots' < vps/restic-adhoc.sh
```

Restore drill (restores to `/root/restore-drill` on the VM), then compare with the live dumps and delete the copy:

```bash
ssh root@homelab-vps 'bash -s -- restore latest --target /restore' < vps/restic-adhoc.sh
```

```bash
ssh root@homelab-vps 'for f in fleet authentik; do cmp -s /root/restore-drill/dumps/$f.sql /var/lib/docker/volumes/backup_dumps/_data/$f.sql && echo "$f: matches" || echo "$f: DIFFERS"; done; rm -rf /root/restore-drill'
```

A drill run after the nightly backup but before the next dump should match exactly.

### NAS side

[`nas-restic-setup.sh`](nas-restic-setup.sh) is the one-time Synology setup (already done 2026-11-17): the `restic` user (key auth, SFTP only, no shell), the `backups` shared folder on `/volume2` with `homelab-vps/` inside, the restic public key, SFTP turned on, and `restic` denied on the `Plex` share (the `users` group can read it). It needs root, so it runs with your sudo password:

```bash
ssh admin@10.253.20.10 'cat > /tmp/nas-restic-setup.sh' < vps/nas-restic-setup.sh
```

```bash
ssh -t admin@10.253.20.10 'sudo sh /tmp/nas-restic-setup.sh; rm -f /tmp/nas-restic-setup.sh'
```

DSM chroots SFTP users to the shared-folder root, which is why the repository path is `/backups/homelab-vps`, not `/volume2/...`. If you regenerate the restic key, update `PUBKEY` in the script and run it again.

Later hardening: run `rest-server --append-only` on the NAS and point restic at it. A compromised VM then could not delete backups, and pruning would move to a trusted job on the NAS.

## Building the VM from scratch

Use this to rebuild after a loss, or as a record of how it was set up.

1. **HCP Terraform workspace** `homelab-vps` in organization `kitzy_net`: CLI-driven, no VCS connection, Execution Mode **Local**. Running `terraform init` creates a missing workspace with the org default (Remote), which breaks CI, so set it to Local by hand. The org token is the `Terraform Cloud` item in the 1Password `GitHub` vault.
2. **Vultr API key** in the 1Password `GitHub` vault as `Vultr API Key` (field `credential`). Its IP allowlist must allow any IPv4 (`0.0.0.0/0`) and IPv6 (`::/0`) because GitHub runners change IPs. Allowlist changes take a minute or two to take effect.

    > **Risk:** with an open allowlist, anyone who gets the key can manage the whole Vultr account, including deleting the VM. Rotate it if it leaks. A self-hosted runner with a fixed IP would remove the need.

3. **Tailscale:** `tag:vps` must exist in [`tailscale/policy.hujson`](../tailscale/policy.hujson). Terraform mints the join key with the `Tailscale ACL` OAuth client (scope `all`; it needs at least `auth_keys` write and must own `tag:vps`).
4. **Apply:** a change under `vps/terraform/` merged to `main` runs `terraform apply`. To replace an existing VM you must first remove `prevent_destroy` on purpose. Within a few minutes `homelab-vps` joins the tailnet:

    ```bash
    ssh root@homelab-vps 'cloud-init status --long; docker version --format "{{.Server.Version}}"; swapon --show; docker network ls | grep proxy'
    ```

    Scan the public IP from outside the tailnet: every TCP port should be filtered.

5. **Doco-CD token:** the service account `doco-cd-homelab-vps` has read-only access to the `Homelab` vault only (service accounts cannot read Personal vaults). Write its token to the VM without echoing it. The item title has parentheses, so look it up by ID:

    ```bash
    id=$(op item list --vault Homelab --format json | python3 -c 'import json,sys;print([i["id"] for i in json.load(sys.stdin) if i["title"]=="Doco-CD service account (homelab-vps)"][0])'); op read "op://Homelab/$id/credential" | ssh root@homelab-vps 'umask 077; cat > /opt/doco-cd/op_token'
    ```

6. **For a restore,** set `profiles: []` on `authentik` and `fleet` in `.doco-cd.yml` first, then follow [Disaster recovery](#disaster-recovery). For an empty install, leave `profiles: [app]`.
7. **Start Doco-CD:**

    ```bash
    ssh root@homelab-vps 'cd /opt/doco-cd && docker compose up -d && docker compose logs --tail 50'
    ```

8. **Enroll the VM in Fleet:** build a Linux package with `fleetctl package --type=deb --enable-scripts --fleet-url=https://fleet.kitzy.net --enroll-secret=<secret from Fleet>`, copy it to the VM over SSH, and `dpkg -i` it. Delete the `.deb` afterwards, because it contains the enroll secret.

The Cloudflare tunnel token and DNS records do not change on a rebuild, so traffic returns as soon as `cloudflared` connects.

## Disaster recovery

Restoring Authentik and Fleet onto a new VM from the restic backups. This follows the procedure used for the K3s migration, which was tested end to end.

1. **Build the VM** with `profiles: []` ([Building the VM from scratch](#building-the-vm-from-scratch), steps 1–7). Only the databases, Redis, and cloudflared start. Confirm no app container ever started:

    ```bash
    ssh root@homelab-vps 'docker ps -a --format "{{.Names}}" | grep -E "authentik-server|authentik-worker|fleet-fleet-1|fleet-migrate" || echo "no app containers: good"'
    ```

2. **Restore the latest dumps** from restic. Doco-CD has created the stopped `backup-restic-backup-1` container, which `restic-adhoc.sh` needs:

    ```bash
    ssh root@homelab-vps 'bash -s -- snapshots' < vps/restic-adhoc.sh
    ```

    ```bash
    ssh root@homelab-vps 'bash -s -- restore latest --target /restore' < vps/restic-adhoc.sh
    ```

    The dumps land in `/root/restore-drill/dumps/` as plain SQL, and the Authentik media in `/root/restore-drill/data/authentik_media/`.

3. **Load them** into the empty databases, using the credentials already in each container's env:

    ```bash
    ssh root@homelab-vps 'set -o pipefail; docker exec -i fleet-fleet-mysql-1 sh -c "MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysql -uroot fleet" < /root/restore-drill/dumps/fleet.sql && docker exec fleet-fleet-mysql-1 sh -c "MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysql -uroot -N fleet -e \"SELECT COUNT(*) FROM hosts\""'
    ```

    ```bash
    ssh root@homelab-vps 'set -o pipefail; docker exec -i authentik-authentik-db-1 sh -c "psql -q -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\"" < /root/restore-drill/dumps/authentik.sql >/dev/null && echo authentik restored'
    ```

    ```bash
    ssh root@homelab-vps 'tar -C /root/restore-drill/data/authentik_media -c . | docker run -i --rm -v authentik_media:/media busybox:1.38.0 tar -x -C /media'
    ```

    If a restore fails partway, do not retry on top of it. Drop and recreate the database as the superuser, then run it again.

4. **Start the apps:** set `profiles: [app]` again and merge. Watch `docker logs fleet-fleet-migrate-1` and the Authentik server logs. Fleet needs the same `FLEET_SERVER_PRIVATE_KEY` the data was written with. If it is wrong, Fleet crash-loops with `decrypting mdm config asset ... message authentication failed`.
5. **Verify:** `https://fleet.kitzy.net/healthz` and `https://auth.kitzy.net/-/health/ready/` return 200, Fleet hosts check in, an SSO login works. Delete `/root/restore-drill`.

## Migration history

In November 2026 the Proxmox cluster went down, and the apps moved from K3s to this VM. The cluster went offline about 2026-11-13. The VM went live and DNS was cut over on 2026-11-17, with data restored from the last nightly dumps (2026-11-13). Scanopy was dropped as unused.

Findings worth keeping:

- A Vultr firewall group with no rules allows all inbound traffic. Public SSH was reachable for about 15 minutes after the first apply (no attempts logged) until the UDP 41641 rule and the `sshd` shutdown went in.
- Compose `configs` are injected only when Compose starts a container, so `docker start` on a job container that Doco-CD created would miss them. The backup scripts therefore live in `command`.
- A Compose project whose services are all profile-gated fails with "no service selected", so the backup stack is gated by `BACKUP_JOBS_ENABLED` instead of a profile.
- pg_dump 17.6+ writes `\unrestrict` lines after its completion footer, so the footer check reads the last 20 lines.
- Deleting a stacked PR's base branch on GitHub closes the PRs stacked on it instead of retargeting them. Retarget them to `main` first.
- The `dns` Terraform had been failing since 2026-07-12 because its state still held `kitzysound.com`, which moved to [kitzy/kitzysound.com](https://github.com/kitzy/kitzysound.com). The stale state was removed and the zone file deleted.
- After the cutover, the old cluster's Tailscale devices, OAuth clients, Flux deploy key, Cloudflare tunnel, and credentials were deleted. The old iSCSI LUNs, the `k8s-backups` share, the `democratic-csi` DSM user, and the two 1Password items that open them (`iSCSI CHAP - k3s-storage`, `Synology DSM - democratic-csi`) are kept on the Synology until they are decommissioned.

## Security notes

- Doco-CD mounts the Docker socket, which is root-equivalent on the VM. The 1Password token also lives on the VM. Keep the service account scoped to one vault, read-only.
- Fleet's agent runs with scripts enabled. Fleet admin access is therefore root access to this VM, and through Docker to every database on it.
- The Tailscale bootstrap key is in the instance `user_data`, which the Vultr metadata service serves to anything on the VM. It is single-use and expires an hour after it is minted.
- No public inbound TCP ports. Admin access is Tailscale SSH only (check mode).
- Rotate the 1Password service account token, the Vultr API key, and the Fleet enroll secret if the VM is rebuilt or suspected compromised.
