# Backup worker for the DigitalOcean app (component `backup`).
#
# App Platform builds this image from the repo (public, so no registry or
# GitHub app is needed). entrypoint.sh optionally runs the nightly job once,
# then runs supercronic in the foreground; the jobs are in crontab. See
# do/README.md.
#
# Tools:
#   mysqldump    Oracle's 8.4 LTS client from repo.mysql.com. MariaDB's
#                client can fail against MySQL 8 auth.
#   restic       static binary from the official image
#   supercronic  cron for containers, checksum-pinned

FROM restic/restic:0.19.1 AS restic

FROM postgres:17.12-bookworm

ARG SUPERCRONIC_VERSION=v0.2.51
ARG SUPERCRONIC_SHA256=cc232108374e8e2b537045f2d5eaa1229f619db314c3ba6a14d38b35dc0aa123

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2025 \
      | gpg --dearmor -o /usr/share/keyrings/mysql.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian bookworm mysql-8.4-lts" \
      > /etc/apt/sources.list.d/mysql.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends mysql-client; \
    curl -fsSLo /usr/local/bin/supercronic \
      "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64"; \
    echo "${SUPERCRONIC_SHA256}  /usr/local/bin/supercronic" | sha256sum -c -; \
    chmod +x /usr/local/bin/supercronic; \
    apt-get purge -y gnupg; apt-get autoremove -y; rm -rf /var/lib/apt/lists/*

COPY --from=restic /usr/bin/restic /usr/local/bin/restic
COPY crontab /etc/backup/crontab
COPY backup.sh entrypoint.sh /usr/local/bin/
# A separate chmod, not COPY --chmod: App Platform's builder ignores --chmod.
RUN chmod 0755 /usr/local/bin/backup.sh /usr/local/bin/entrypoint.sh

# Unprivileged. ("backup" is already a Debian system user.)
RUN useradd --create-home --uid 10001 dbbackup && install -d -o dbbackup /dumps /cache
USER dbbackup
ENV RESTIC_CACHE_DIR=/cache

# Replace the postgres image's docker-entrypoint.sh, which isn't needed here.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
