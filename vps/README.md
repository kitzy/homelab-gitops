# homelab-vps

One Vultr VM runs Authentik, Fleet, and Scanopy as Docker Compose stacks. [Doco-CD](https://doco.cd) on the VM polls this repo and deploys the stacks listed in [`.doco-cd.yml`](../.doco-cd.yml). This replaces the K3s, Flux, and Proxmox stack under [`kubernetes/`](../kubernetes/), which stays in the repo until the old data is decommissioned.

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
| `scanopy` | `scanopy-db`, `scanopy-server`, `scanopy-ts` (Tailscale sidecar) | tailnet only, `https://scanopy.tail26a1d8.ts.net` |

Conventions:

- Every image tag is pinned. Renovate covers `compose/*/compose.yaml` (see [`renovate.json`](../renovate.json)). It keeps MySQL on 8.0, Postgres on 17, and Redis on 7.
- Named volumes only, with fixed names (`fleet_mysql`, `authentik_pgdata`, ...). No bind mounts from the repo: Doco-CD runs in a container, so a relative path would resolve somewhere the Docker daemon cannot see. Config files use `configs` with inline `content`.
- `proxy` is an external network created by cloud-init. Only cloudflared and the apps' HTTP services join it. Databases stay on each stack's own network (`authentik-backend`, `fleet-backend`, `scanopy-backend`), which have fixed names so the backup stack can join them.
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
  | scanopy-server | 512 MB |
  | scanopy-db | 384 MB |
  | cloudflared, scanopy-ts | 192 MB |
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
| `Scanopy Secrets` | `POSTGRES_PASSWORD` | exists |
| `Cloudflare Tunnel` | `VPS_TUNNEL_TOKEN` (new field, token of the new `homelab-vps` tunnel; the old `TUNNEL_TOKEN` stays for rollback) | **create** |
| `Scanopy Tailscale` | `credential`: a reusable=false, pre-authorized, `tag:vps` auth key | **create** |

Creating the two new items:

1. Tunnel: Cloudflare Zero Trust, Networks, Tunnels, create a Cloudflared tunnel named `homelab-vps`. Copy its token into a new `VPS_TUNNEL_TOKEN` field on `Cloudflare Tunnel`, and note the tunnel ID for the DNS PR. Do not add public hostnames in the dashboard. The `dns/` Terraform manages them.
2. Scanopy key: in the Tailscale admin console, first delete the old `scanopy` device (the K8s ingress proxy), or the new node registers as `scanopy-1` and the URL changes. Then generate an auth key: not reusable, pre-authorized, tag `tag:vps`. Store it as an API Credential item `Scanopy Tailscale` in `Homelab`, with the key in `credential`. The sidecar uses it once and keeps its node state in the `scanopy_ts_state` volume.

## Security notes

- Doco-CD mounts the Docker socket, which is root-equivalent on the VM. The 1Password token also lives on the VM. Keep the service account scoped to one vault, read-only.
- The Tailscale bootstrap key is in the instance `user_data`, which the Vultr metadata service serves to anything on the VM. It is single-use and expires an hour after it is minted, so it is spent by the time anything else runs.
- No public inbound ports. Admin access is Tailscale SSH only (check mode).
- Rotate the 1Password service account token and the Vultr API key if the VM is rebuilt or suspected compromised.
