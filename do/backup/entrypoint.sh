#!/bin/bash
# Starts the backup worker. With BACKUP_RUN_ON_START=true (rehearsal mode in
# do/terraform/app.tf), runs the nightly job once first, so a deploy produces
# a backup right away. A failure is logged but doesn't stop the worker:
# supercronic still needs to run the schedule.
if [ "${BACKUP_RUN_ON_START:-}" = "true" ]; then
  echo "[start] BACKUP_RUN_ON_START=true: running the nightly job once"
  /usr/local/bin/backup.sh nightly || echo "[start] nightly job FAILED on start (see above)"
fi
exec supercronic -passthrough-logs /etc/backup/crontab
