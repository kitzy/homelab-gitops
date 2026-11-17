#!/usr/bin/env bash
# Run an ad-hoc restic command against the homelab-vps repository on the NAS.
#
# Run it on the VM from your Mac; the script is piped over SSH:
#
#   ssh root@homelab-vps 'bash -s -- snapshots' < vps/restic-adhoc.sh
#   ssh root@homelab-vps 'bash -s -- check' < vps/restic-adhoc.sh
#   ssh root@homelab-vps 'bash -s -- restore latest --target /restore' < vps/restic-adhoc.sh
#
# It reads the repository settings, SSH key, and pinned NAS host key from the
# environment of the restic-backup job container that Doco-CD created
# (stopped between runs), so nothing secret is kept on the host. The env file
# it writes is mode 600 in a temp dir and removed on exit.
#
# Mounts: backup_dumps (read-only) at /dumps, restic_cache at /cache, and
# $RESTORE_DIR (default /root/restore-drill) at /restore.
set -euo pipefail

job=backup-restic-backup-1
image=restic/restic:0.19.1
restore_dir=${RESTORE_DIR:-/root/restore-drill}

if ! docker inspect "$job" >/dev/null 2>&1; then
  echo "Container $job not found. Has Doco-CD deployed the backup stack?" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
chmod 700 "$work"
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$job" | grep -E '^RESTIC_' > "$work/env"
chmod 600 "$work/env"
mkdir -p "$restore_dir"

tty_flag=()
[ -t 0 ] && tty_flag=(-it)

# The SSH setup matches the restic_env config in compose/backup/compose.yaml.
# shellcheck disable=SC2016 # expanded inside the container
setup='mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
printf "%s" "$RESTIC_SSH_KEY_B64" | base64 -d > "$HOME/.ssh/id_restic"
printf "%s\n" "$RESTIC_NAS_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts_nas"
chmod 600 "$HOME/.ssh/id_restic"
printf "Host nas\n  HostName 10.253.20.10\n  User restic\n  IdentityFile ~/.ssh/id_restic\n  IdentitiesOnly yes\n  UserKnownHostsFile ~/.ssh/known_hosts_nas\n  StrictHostKeyChecking yes\n  ServerAliveInterval 30\n  ServerAliveCountMax 10\n" > "$HOME/.ssh/config"
exec restic "$@"'

docker run --rm ${tty_flag[@]+"${tty_flag[@]}"} \
  --env-file "$work/env" \
  -v backup_dumps:/dumps:ro \
  -v restic_cache:/cache \
  -v "$restore_dir:/restore" \
  --entrypoint sh "$image" -c "$setup" restic "$@"
