#!/bin/bash
# Usage: backup.sh nightly|check
#
# nightly: mysqldump Fleet, pg_dump Authentik, check both, restic backup to
#          R2, then retention (7 daily, 4 weekly, 3 monthly) and prune.
#          Creates the repository on its first run.
# check:   restic check.
#
# Environment (set in the app spec, see do/terraform/app.tf):
#   FLEET_DB_HOST/PORT/USER/PASSWORD/NAME, FLEET_DB_CA     (CA certificate PEM)
#   AUTHENTIK_DB_HOST/PORT/USER/PASSWORD/NAME, AUTHENTIK_DB_CA
#   RESTIC_REPOSITORY, RESTIC_PASSWORD, AWS_ACCESS_KEY_ID,
#   AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION=auto, RESTIC_HOST
#   HC_BACKUP_URL, HC_CHECK_URL  Healthchecks.io ping URLs; empty = no pings
set -uo pipefail

job=${1:?usage: backup.sh nightly|check}
dumps=/dumps
certs=$(mktemp -d)
trap 'rm -rf "$certs"' EXIT
printf '%s\n' "$FLEET_DB_CA" > "$certs/mysql-ca.pem"
printf '%s\n' "$AUTHENTIK_DB_CA" > "$certs/pg-ca.pem"

log() { echo "[$job] $*"; }

hc_ping() { # $1 = URL, $2 = "" | /start | /fail
  [ -n "$1" ] || return 0
  curl -fsS -m 10 --retry 3 -o /dev/null "$1$2" || log "WARN: Healthchecks ping '$2' failed"
}

dump_fleet() {
  local out=$dumps/fleet.sql tmp=$dumps/fleet.sql.tmp tables t
  log "Dumping Fleet MySQL"
  MYSQL_PWD=$FLEET_DB_PASSWORD mysqldump \
    --host="$FLEET_DB_HOST" --port="$FLEET_DB_PORT" --user="$FLEET_DB_USER" \
    --ssl-mode=VERIFY_IDENTITY --ssl-ca="$certs/mysql-ca.pem" \
    --single-transaction --routines --triggers --events --set-gtid-purged=OFF \
    "$FLEET_DB_NAME" > "$tmp" || { rm -f "$tmp"; return 1; }
  # Same checks as the VM's job: enough tables, and the core tables present.
  tables=$(grep -c "^-- Table structure for table" "$tmp" || true)
  if [ "$tables" -lt 100 ]; then
    log "ERROR: only $tables tables in the Fleet dump (expected 100+)"; rm -f "$tmp"; return 1
  fi
  for t in users migration_status_tables hosts; do
    grep -q "Table structure for table \`$t\`" "$tmp" || { log "ERROR: Fleet dump is missing $t"; rm -f "$tmp"; return 1; }
  done
  mv "$tmp" "$out"
  log "Fleet dump OK: $tables tables, $(du -h "$out" | cut -f1)"
}

dump_authentik() {
  local out=$dumps/authentik.sql tmp=$dumps/authentik.sql.tmp
  log "Dumping Authentik PostgreSQL"
  PGPASSWORD=$AUTHENTIK_DB_PASSWORD PGSSLMODE=verify-full PGSSLROOTCERT="$certs/pg-ca.pem" \
    pg_dump --host="$AUTHENTIK_DB_HOST" --port="$AUTHENTIK_DB_PORT" \
    --username="$AUTHENTIK_DB_USER" --format=plain "$AUTHENTIK_DB_NAME" > "$tmp" \
    || { rm -f "$tmp"; return 1; }
  # pg_dump writes this footer only when it finishes; 17.6+ adds lines after it.
  tail -n 20 "$tmp" | grep -q "PostgreSQL database dump complete" \
    || { log "ERROR: Authentik dump is incomplete"; rm -f "$tmp"; return 1; }
  mv "$tmp" "$out"
  log "Authentik dump OK: $(du -h "$out" | cut -f1)"
}

ensure_repo() {
  # restic exits 10 only when the repository does not exist, so an auth or
  # network error never triggers an init.
  restic cat config >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq 10 ]; then
    log "Repository not found, initializing it"; restic init || return 1
  elif [ "$rc" -ne 0 ]; then
    log "ERROR: cannot open the repository (restic exit $rc)"; restic cat config >/dev/null; return 1
  fi
}

nightly() {
  dump_fleet || return 1
  dump_authentik || return 1
  ensure_repo || return 1
  restic backup --host "$RESTIC_HOST" --tag nightly "$dumps/fleet.sql" "$dumps/authentik.sql" || return 1
  restic forget --host "$RESTIC_HOST" --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune || return 1
  restic snapshots --host "$RESTIC_HOST" --latest 1 || return 1
  # The dumps are in the snapshot; free the temporary disk (4 GiB limit).
  rm -f "$dumps/fleet.sql" "$dumps/authentik.sql"
}

check() {
  restic check
}

case $job in
  nightly) hc=${HC_BACKUP_URL:-} ;;
  check)   hc=${HC_CHECK_URL:-} ;;
  *) echo "usage: backup.sh nightly|check" >&2; exit 2 ;;
esac

hc_ping "$hc" /start
if "$job"; then
  log "OK"; hc_ping "$hc" ""
else
  log "FAILED"; hc_ping "$hc" /fail; exit 1
fi
