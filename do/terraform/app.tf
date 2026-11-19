# Three App Platform apps: authentik, fleet (with Redis and the migration
# job) and backups. Separate apps deploy, fail and roll back independently,
# and each database firewall admits only the apps that use that database.
#
# FIRST CREATION of an app: Terraform only learns an app's ID after its first
# deploy finishes, but that deploy needs the database firewall to admit the
# app. Right after an app appears in the API, add the same trusted-source
# rules Terraform will apply (see do/README.md); the long first-boot health
# check windows leave time for it.
#
# REHEARSAL MODE (local.rehearsal = true; used before the cutover on
# 2026-11-18, kept for rebuilding a rehearsal environment):
#   - The databases are empty. Fleet and Authentik create fresh schemas. A
#     second Fleet or Authentik on a copy of production would run production's
#     background jobs (webhooks, Apple MDM/ABM sync, SCIM/LDAP sync).
#   - Fleet has no R2 bucket set: its cleanup job deletes installer objects
#     its database doesn't reference, and the rehearsal database references
#     none. (The R2 keys are in place, unused.)
#   - Authentik starts with a random bootstrap password, so its initial-setup
#     flow is closed. Fleet's setup is completed right after the first deploy
#     through the fleet app's default URL.
#   - Domains are auth-do.kitzy.net and fleet-do.kitzy.net.
#   - Healthchecks.io pings are off (HC_ENABLED), so the rehearsal can't
#     signal the VM's checks.
#   - The backup worker runs its nightly job once on every deploy.
#
# ENV VARS. App Platform stores SECRET values encrypted and returns only the
# ciphertext, so the provider always sees them as changed and every apply
# would redeploy every app. Therefore:
#   - Component env is all type GENERAL and fully managed. Database passwords
#     are GENERAL too: the value is a `${db.PASSWORD}` reference that App
#     Platform resolves at runtime, not the password itself.
#   - Real secrets are app-level SECRET env with ignore_changes. Terraform
#     sets them when an app is created (or when the ignore is lifted) and
#     never diffs them afterwards. To rotate one: update 1Password, then in
#     one PR remove `spec[0].env` from that app's ignore_changes, apply, and
#     put it back in a follow-up PR.
#
# App Platform notes:
#   - run_command replaces the image's ENTRYPOINT, so Authentik's commands
#     spell out `dumb-init -- ak ...`.
#   - The database CA certificates arrive as env vars; the run commands write
#     them to /tmp so Fleet and Authentik can verify the server.
#   - `$${...}` is Terraform's escape for App Platform's `${...}` bindable
#     variables.

locals {
  # Rehearsal ended at the cutover on 2026-11-18 (see REHEARSAL MODE above).
  rehearsal = false

  domains = local.rehearsal ? {
    authentik = "auth-do.kitzy.net"
    fleet     = "fleet-do.kitzy.net"
    } : {
    authentik = "auth.kitzy.net"
    fleet     = "fleet.kitzy.net"
  }

  # Image tags: Renovate reads the `# renovate:` comments (renovate.json).
  fleet_image = {
    registry   = "fleetdm"
    repository = "fleet"
    # renovate: datasource=docker depName=fleetdm/fleet
    tag = "v4.95.0"
  }
  authentik_image = {
    registry   = "goauthentik"
    repository = "server"
    # renovate: datasource=docker depName=ghcr.io/goauthentik/server
    tag = "2026.8.5"
  }

  # Writes the CA to a file and execs the command. Runs under /bin/sh.
  # format() fills the last %s; %%s is printf's literal %s.
  fleet_cmd     = "sh -c 'printf \"%%s\\n\" \"$FLEET_MYSQL_CA_PEM\" > /tmp/mysql-ca.pem && exec fleet %s'"
  authentik_cmd = "sh -c 'printf \"%%s\\n\" \"$AUTHENTIK_PG_CA_PEM\" > /tmp/pg-ca.pem && exec dumb-init -- ak %s'"

  fleet_mysql_env = {
    FLEET_MYSQL_ADDRESS  = "$${fleet-mysql.HOSTNAME}:$${fleet-mysql.PORT}"
    FLEET_MYSQL_USERNAME = "$${fleet-mysql.USERNAME}"
    FLEET_MYSQL_PASSWORD = "$${fleet-mysql.PASSWORD}"
    FLEET_MYSQL_DATABASE = "$${fleet-mysql.DATABASE}"
    FLEET_MYSQL_TLS_CA   = "/tmp/mysql-ca.pem"
    FLEET_MYSQL_CA_PEM   = "$${fleet-mysql.CA_CERT}"
  }

  fleet_server_env = merge(local.fleet_mysql_env, {
    FLEET_SERVER_ADDRESS                          = "0.0.0.0:8080"
    FLEET_SERVER_TLS                              = "false"
    FLEET_LOGGING_JSON                            = "true"
    FLEET_SERVER_MAX_INSTALLER_SIZE               = "20G"
    FLEET_SESSION_DURATION                        = "1h"
    FLEET_REDIS_ADDRESS                           = "redis:6379"
    FLEET_VULNERABILITIES_DATABASES_PATH          = "/tmp/vulndb"
    FLEET_VULNERABILITIES_PERIODICITY             = "1h"
    FLEET_VULNERABILITIES_CURRENT_INSTANCE_CHECKS = "yes"
    FLEET_OSQUERY_HOST_IDENTIFIER                 = "uuid"
    FLEET_OSQUERY_LABEL_UPDATE_INTERVAL           = "1m"
    }, local.rehearsal ? {} : {
    # Software installers, icons, bootstrap packages and org logos in R2.
    # The key pair is app-level SECRET env. Region must be set, or Fleet asks
    # AWS for the bucket's region at startup.
    FLEET_S3_SOFTWARE_INSTALLERS_BUCKET       = cloudflare_r2_bucket.fleet_installers.name
    FLEET_S3_SOFTWARE_INSTALLERS_ENDPOINT_URL = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
    FLEET_S3_SOFTWARE_INSTALLERS_REGION       = "auto"
  })

  authentik_env = {
    AUTHENTIK_POSTGRESQL__HOST          = "$${authentik-pg.HOSTNAME}"
    AUTHENTIK_POSTGRESQL__PORT          = "$${authentik-pg.PORT}"
    AUTHENTIK_POSTGRESQL__NAME          = "$${authentik-pg.DATABASE}"
    AUTHENTIK_POSTGRESQL__USER          = "$${authentik-pg.USERNAME}"
    AUTHENTIK_POSTGRESQL__PASSWORD      = "$${authentik-pg.PASSWORD}"
    AUTHENTIK_POSTGRESQL__SSLMODE       = "verify-full"
    AUTHENTIK_POSTGRESQL__SSLROOTCERT   = "/tmp/pg-ca.pem"
    AUTHENTIK_PG_CA_PEM                 = "$${authentik-pg.CA_CERT}"
    AUTHENTIK_HOST                      = local.domains.authentik
    AUTHENTIK_COOKIE_DOMAIN             = "kitzy.net"
    AUTHENTIK_ERROR_REPORTING__ENABLED  = "false"
    AUTHENTIK_DISABLE_UPDATE_CHECK      = "true"
    AUTHENTIK_DISABLE_STARTUP_ANALYTICS = "true"
    AUTHENTIK_LOG_LEVEL                 = "info"
    # Uploaded files (icons, logos, backgrounds) in R2: App Platform has no
    # shared volume for the local backend. Keys are app-level SECRET env.
    AUTHENTIK_STORAGE__BACKEND         = "s3"
    AUTHENTIK_STORAGE__S3__ENDPOINT    = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
    AUTHENTIK_STORAGE__S3__REGION      = "auto"
    AUTHENTIK_STORAGE__S3__BUCKET_NAME = cloudflare_r2_bucket.authentik_files.name
  }

  authentik_server_env = merge(local.authentik_env, {
    AUTHENTIK_LISTEN__HTTP = "0.0.0.0:9000"
    AUTHENTIK_WEB__WORKERS = "1" # 2 ran the 1 GB instance at 98% RAM (2026-11-18)
    # App Platform's edge proxies reach the container from private
    # addresses. Verified 2026-11-18: Authentik logs the real client IP.
    AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS = "10.0.0.0/8,172.16.0.0/12,100.64.0.0/10"
    AUTHENTIK_AVATARS                     = "gravatar,initials"
  })

  backup_env = {
    FLEET_DB_HOST         = "$${fleet-mysql.HOSTNAME}"
    FLEET_DB_PORT         = "$${fleet-mysql.PORT}"
    FLEET_DB_USER         = "$${fleet-mysql.USERNAME}"
    FLEET_DB_PASSWORD     = "$${fleet-mysql.PASSWORD}"
    FLEET_DB_NAME         = "$${fleet-mysql.DATABASE}"
    FLEET_DB_CA           = "$${fleet-mysql.CA_CERT}"
    AUTHENTIK_DB_HOST     = "$${authentik-pg.HOSTNAME}"
    AUTHENTIK_DB_PORT     = "$${authentik-pg.PORT}"
    AUTHENTIK_DB_USER     = "$${authentik-pg.USERNAME}"
    AUTHENTIK_DB_PASSWORD = "$${authentik-pg.PASSWORD}"
    AUTHENTIK_DB_NAME     = "$${authentik-pg.DATABASE}"
    AUTHENTIK_DB_CA       = "$${authentik-pg.CA_CERT}"
    RESTIC_REPOSITORY     = "s3:https://${var.cloudflare_account_id}.r2.cloudflarestorage.com/${cloudflare_r2_bucket.backups.name}"
    AWS_DEFAULT_REGION    = "auto"
    RESTIC_HOST           = "homelab-do"
    HC_ENABLED            = local.rehearsal ? "false" : "true"
    # Rehearsal: back up once on every deploy (see do/backup/entrypoint.sh).
    BACKUP_RUN_ON_START = local.rehearsal ? "true" : "false"
  }

  # App-level SECRET env (see ENV VARS above).
  authentik_secrets = merge(
    {
      AUTHENTIK_SECRET_KEY              = var.authentik_secret_key
      AUTHENTIK_STORAGE__S3__ACCESS_KEY = var.authentik_r2_access_key
      AUTHENTIK_STORAGE__S3__SECRET_KEY = var.authentik_r2_secret_key
    },
    local.rehearsal ? { AUTHENTIK_BOOTSTRAP_PASSWORD = random_password.authentik_bootstrap.result } : {}
  )
  fleet_secrets = {
    FLEET_SERVER_PRIVATE_KEY                       = var.fleet_server_private_key
    FLEET_LICENSE_KEY                              = var.fleet_license_key
    FLEET_S3_SOFTWARE_INSTALLERS_ACCESS_KEY_ID     = var.fleet_r2_access_key_id
    FLEET_S3_SOFTWARE_INSTALLERS_SECRET_ACCESS_KEY = var.fleet_r2_secret_access_key
  }
  backup_secrets = {
    RESTIC_PASSWORD       = var.restic_password
    AWS_ACCESS_KEY_ID     = var.r2_backups_access_key_id
    AWS_SECRET_ACCESS_KEY = var.r2_backups_secret_access_key
    HC_BACKUP_URL         = var.hc_backup_url
    HC_CHECK_URL          = var.hc_check_url
  }
}

resource "random_password" "authentik_bootstrap" {
  length  = 32
  special = false
}

# --- Authentik ----------------------------------------------------------------

resource "digitalocean_app" "authentik" {
  # ignore_changes on spec[0].env lifted for one apply, to remove the
  # rehearsal's AUTHENTIK_BOOTSTRAP_PASSWORD; restored in the next PR.

  spec {
    name   = "authentik"
    region = "nyc"

    alert {
      rule = "DEPLOYMENT_FAILED"
    }
    alert {
      rule = "DOMAIN_FAILED"
    }

    domain {
      name = local.domains.authentik
      type = "PRIMARY"
    }

    database {
      name         = "authentik-pg"
      engine       = "PG"
      production   = true
      cluster_name = digitalocean_database_cluster.authentik_pg.name
      db_name      = digitalocean_database_db.authentik.name
      db_user      = digitalocean_database_user.authentik.name
    }

    dynamic "env" {
      for_each = local.authentik_secrets
      content {
        key   = env.key
        value = env.value
        scope = "RUN_TIME"
        type  = "SECRET"
      }
    }

    ingress {
      rule {
        match {
          path {
            prefix = "/"
          }
        }
        component {
          name = "authentik-server"
        }
      }
    }

    service {
      name               = "authentik-server"
      instance_size_slug = "apps-s-1vcpu-1gb-fixed"
      instance_count     = 1
      http_port          = 9000
      run_command        = format(local.authentik_cmd, "server")

      image {
        registry_type = "GHCR"
        registry      = local.authentik_image.registry
        repository    = local.authentik_image.repository
        tag           = local.authentik_image.tag
      }

      health_check {
        http_path             = "/-/health/live/"
        port                  = 9000
        initial_delay_seconds = 120
        period_seconds        = 15
        timeout_seconds       = 10
        # 10+ minutes: the first boot runs every migration, and the firewall
        # rule for a new app is added during its first deploy (see top).
        failure_threshold = 40
      }

      dynamic "env" {
        for_each = local.authentik_server_env
        content {
          key   = env.key
          value = env.value
          scope = "RUN_TIME"
          type  = "GENERAL"
        }
      }
    }

    worker {
      name               = "authentik-worker"
      instance_size_slug = "apps-s-1vcpu-0.5gb"
      instance_count     = 1
      run_command        = format(local.authentik_cmd, "worker")

      image {
        registry_type = "GHCR"
        registry      = local.authentik_image.registry
        repository    = local.authentik_image.repository
        tag           = local.authentik_image.tag
      }

      dynamic "env" {
        for_each = local.authentik_env
        content {
          key   = env.key
          value = env.value
          scope = "RUN_TIME"
          type  = "GENERAL"
        }
      }
    }
  }
}

# --- Fleet ----------------------------------------------------------------------

resource "digitalocean_app" "fleet" {
  # App-level env holds only SECRETs, which App Platform returns encrypted
  # (see ENV VARS at the top).
  lifecycle {
    ignore_changes = [spec[0].env]
  }

  spec {
    name   = "fleet"
    region = "nyc"

    alert {
      rule = "DEPLOYMENT_FAILED"
    }
    alert {
      rule = "DOMAIN_FAILED"
    }

    domain {
      name = local.domains.fleet
      type = "PRIMARY"
    }

    database {
      name         = "fleet-mysql"
      engine       = "MYSQL"
      production   = true
      cluster_name = digitalocean_database_cluster.fleet_mysql.name
      db_name      = digitalocean_database_db.fleet.name
      db_user      = digitalocean_database_user.fleet.name
    }

    dynamic "env" {
      for_each = local.fleet_secrets
      content {
        key   = env.key
        value = env.value
        scope = "RUN_TIME"
        type  = "SECRET"
      }
    }

    ingress {
      rule {
        match {
          path {
            prefix = "/"
          }
        }
        component {
          name = "fleet"
        }
      }
    }

    service {
      name               = "redis"
      instance_size_slug = "apps-s-1vcpu-0.5gb"
      instance_count     = 1
      # Internal only: no http_port and no ingress rule. Fleet uses Redis as
      # a cache, so nothing is persisted.
      internal_ports = [6379]

      image {
        registry_type = "DOCKER_HUB"
        registry      = "library"
        repository    = "redis"
        # renovate: datasource=docker depName=redis
        tag = "7.4.12-alpine"
      }
    }

    # Runs before every deploy: Fleet refuses to serve with pending migrations.
    job {
      name               = "fleet-migrate"
      kind               = "PRE_DEPLOY"
      instance_size_slug = "apps-s-1vcpu-0.5gb"
      instance_count     = 1
      run_command        = format(local.fleet_cmd, "prepare db --no-prompt")

      image {
        registry_type = "DOCKER_HUB"
        registry      = local.fleet_image.registry
        repository    = local.fleet_image.repository
        tag           = local.fleet_image.tag
      }

      dynamic "env" {
        for_each = local.fleet_mysql_env
        content {
          key   = env.key
          value = env.value
          scope = "RUN_TIME"
          type  = "GENERAL"
        }
      }
    }

    service {
      name               = "fleet"
      instance_size_slug = "apps-s-1vcpu-1gb-fixed"
      instance_count     = 1
      http_port          = 8080
      run_command        = format(local.fleet_cmd, "serve")

      image {
        registry_type = "DOCKER_HUB"
        registry      = local.fleet_image.registry
        repository    = local.fleet_image.repository
        tag           = local.fleet_image.tag
      }

      health_check {
        http_path             = "/healthz"
        port                  = 8080
        initial_delay_seconds = 60
        period_seconds        = 15
        timeout_seconds       = 10
        failure_threshold     = 40 # see the first-creation note at the top
      }

      dynamic "env" {
        for_each = local.fleet_server_env
        content {
          key   = env.key
          value = env.value
          scope = "RUN_TIME"
          type  = "GENERAL"
        }
      }
    }
  }
}

# --- Backups --------------------------------------------------------------------

resource "digitalocean_app" "backups" {
  # App-level env holds only SECRETs, which App Platform returns encrypted
  # (see ENV VARS at the top).
  lifecycle {
    ignore_changes = [spec[0].env]
  }

  spec {
    name   = "backups"
    region = "nyc"

    alert {
      rule = "DEPLOYMENT_FAILED"
    }

    database {
      name         = "fleet-mysql"
      engine       = "MYSQL"
      production   = true
      cluster_name = digitalocean_database_cluster.fleet_mysql.name
      db_name      = digitalocean_database_db.fleet.name
      db_user      = digitalocean_database_user.fleet.name
    }
    database {
      name         = "authentik-pg"
      engine       = "PG"
      production   = true
      cluster_name = digitalocean_database_cluster.authentik_pg.name
      db_name      = digitalocean_database_db.authentik.name
      db_user      = digitalocean_database_user.authentik.name
    }

    dynamic "env" {
      for_each = local.backup_secrets
      content {
        key   = env.key
        value = env.value
        scope = "RUN_TIME"
        type  = "SECRET"
      }
    }

    worker {
      name               = "backup"
      instance_size_slug = "apps-s-1vcpu-0.5gb"
      instance_count     = 1
      dockerfile_path    = "do/backup/Dockerfile"
      source_dir         = "do/backup"

      # Public repo, so no GitHub app is needed. Changes to do/backup/ deploy
      # with the next app deploy.
      git {
        repo_clone_url = "https://github.com/kitzy/homelab-gitops.git"
        branch         = "main"
      }

      dynamic "env" {
        for_each = local.backup_env
        content {
          key   = env.key
          value = env.value
          scope = "RUN_TIME"
          type  = "GENERAL"
        }
      }
    }
  }
}
