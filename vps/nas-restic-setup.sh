#!/bin/sh
# One-time Synology setup for restic backups from homelab-vps.
# Run as root on the NAS (DSM 7.2). From your Mac:
#
#   scp vps/nas-restic-setup.sh admin@10.253.20.10:/tmp/
#   ssh -t admin@10.253.20.10 'sudo sh /tmp/nas-restic-setup.sh && rm /tmp/nas-restic-setup.sh'
#
# It creates:
#   - user `restic` (non-admin, random password nobody needs; key auth only)
#   - shared folder `backups` on /volume2, read/write for restic and
#     administrators only, with homelab-vps/ inside it
#   - ~restic/.ssh/authorized_keys with the restic public key
#   - SFTP turned on (DSM had it off)
# Safe to re-run: each step skips what already exists.
set -eu

PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNwwf35HydUspEeX4hLwtoEgZkNKSdrPHyoRa+MlgNb restic@homelab-vps'
SHARE=backups
SHARE_PATH=/volume2/backups
HOME_DIR=/var/services/homes/restic

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)." >&2; exit 1; }
PATH=/usr/syno/sbin:/usr/syno/bin:$PATH

echo "== user"
if synouser --get restic >/dev/null 2>&1; then
  echo "restic exists"
else
  pw=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)
  synouser --add restic "$pw" "restic backups (homelab-vps)" 0 "" 0
  echo "created restic"
fi

echo "== shared folder"
if synoshare --get "$SHARE" >/dev/null 2>&1; then
  echo "$SHARE exists"
else
  # synoshare --add name desc path no-access rw ro browseable adv_privilege
  synoshare --add "$SHARE" "restic repositories (homelab-vps)" "$SHARE_PATH" "" "restic,@administrators" "" 1 0
  echo "created $SHARE at $SHARE_PATH"
fi
mkdir -p "$SHARE_PATH/homelab-vps"
chown restic:users "$SHARE_PATH/homelab-vps"
chmod 700 "$SHARE_PATH/homelab-vps"

echo "== deny other shares"
# New users inherit the `users` group's access. On this NAS that includes
# Plex (found 2026-11-17). Add any other share `restic` can see here.
for other in Plex; do
  synoshare --setuser "$other" NA + restic && echo "restic denied on $other"
done

echo "== ssh key"
mkdir -p "$HOME_DIR/.ssh"
grep -qxF "$PUBKEY" "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null || echo "$PUBKEY" >> "$HOME_DIR/.ssh/authorized_keys"
chown -R restic:users "$HOME_DIR"
# DSM's sshd ignores authorized_keys if the home or .ssh is group/world writable.
chmod 755 "$HOME_DIR"
chmod 700 "$HOME_DIR/.ssh"
chmod 600 "$HOME_DIR/.ssh/authorized_keys"

echo "== SFTP"
if synowebapi --exec api=SYNO.Core.FileServ.FTP.SFTP method=set version=1 enable=true >/dev/null 2>&1; then
  echo "SFTP enabled"
else
  echo "Could not enable SFTP from the CLI. Turn it on in DSM: Control Panel > File Services > FTP > SFTP."
fi

echo
echo "Done. In DSM, check Control Panel > User > restic > Permissions: read/write on"
echo "'$SHARE' only, and no access to every other shared folder."
