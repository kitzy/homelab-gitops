# Two App Platform apps: fleet (with Redis and the migration job) and
# backups. Separate apps deploy, fail and roll back independently, and the
# database firewall admits only the apps that use the database. (Authentik
# was a third app until 2026-11-19; Fleet's SSO and IdP data now come from
# Google Workspace, see google/README.md.)
#
# FIRST CREATION of an app: Terraform only learns an app's ID after its first
# deploy finishes, but that deploy needs the database firewall to admit the
# app. Right after an app appears in the API, add the same trusted-source
# rules Terraform will apply (see do/README.md); the long first-boot health
# check windows leave time for it.
#
# REHEARSAL MODE (local.rehearsal = true; used before the cutover on
# 2026-11-18, kept for rebuilding a rehearsal environment):
#   - The database is empty and Fleet creates a fresh schema. A second Fleet
#     on a copy of production would run production's background jobs
#     (webhooks, Apple MDM/ABM sync).
#   - Fleet has no R2 bucket set: its cleanup job deletes installer objects
#     its database doesn't reference, and the rehearsal database references
#     none. (The R2 keys are in place, unused.) Complete Fleet's setup right
#     after the first deploy through the app's default URL.
#   - The domain is fleet-do.kitzy.net.
#   - Healthchecks.io pings are off (HC_ENABLED).
#   - The backup worker runs its nightly job once on every deploy.
#
# ENV VARS. App Platform stores SECRET values encrypted and returns only the
# ciphertext, so the provider always sees them as changed and every apply
# would redeploy every app. Therefore:
#   - Component env is all type GENERAL and fully managed. The database
#     password is a `${db.PASSWORD}` reference that App Platform resolves at
#     runtime, not the password itself.
#   - Real secrets are app-level SECRET env with ignore_changes. Terraform
#     sets them when an app is created (or when the ignore is lifted) and
#     never diffs them afterwards. To rotate one: update 1Password, then in
#     one PR remove `spec[0].env` from that app's ignore_changes, apply, and
#     put it back in a follow-up PR.
#
# App Platform notes:
#   - run_command replaces the image's ENTRYPOINT.
#   - The database CA certificate arrives as an env var; the run command
#     writes it to /tmp so Fleet can verify the server.
#   - `$${...}` is Terraform's escape for App Platform's `${...}` bindable
#     variables.

locals {
  # Rehearsal ended at the cutover on 2026-11-18 (see REHEARSAL MODE above).
  rehearsal = false

  domains = local.rehearsal ? {
    fleet = "fleet-do.kitzy.net"
    } : {
    fleet = "fleet.kitzy.net"
  }

  # Image tags: Renovate reads the `# renovate:` comments (renovate.json).
  fleet_image = {
    registry   = "fleetdm"
    repository = "fleet"
    # renovate: datasource=docker depName=fleetdm/fleet
    tag = "v4.96.0"
  }
  # Writes the CA to a file and execs the command. Runs under /bin/sh.
  # format() fills the last %s; %%s is printf's literal %s.
  fleet_cmd = "sh -c 'printf \"%%s\\n\" \"$FLEET_MYSQL_CA_PEM\" > /tmp/mysql-ca.pem && exec fleet %s'"

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

  backup_env = {
    FLEET_DB_HOST      = "$${fleet-mysql.HOSTNAME}"
    FLEET_DB_PORT      = "$${fleet-mysql.PORT}"
    FLEET_DB_USER      = "$${fleet-mysql.USERNAME}"
    FLEET_DB_PASSWORD  = "$${fleet-mysql.PASSWORD}"
    FLEET_DB_NAME      = "$${fleet-mysql.DATABASE}"
    FLEET_DB_CA        = "$${fleet-mysql.CA_CERT}"
    RESTIC_REPOSITORY  = "s3:https://${var.cloudflare_account_id}.r2.cloudflarestorage.com/${cloudflare_r2_bucket.backups.name}"
    AWS_DEFAULT_REGION = "auto"
    RESTIC_HOST        = "homelab-do"
    HC_ENABLED         = local.rehearsal ? "false" : "true"
    # Rehearsal: back up once on every deploy (see do/backup/entrypoint.sh).
    BACKUP_RUN_ON_START = local.rehearsal ? "true" : "false"
  }

  # App-level SECRET env (see ENV VARS above).
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
