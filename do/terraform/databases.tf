# Managed databases for the DigitalOcean move (see do/README.md).
#
# Both are single-node Standard-edition clusters in nyc3. DigitalOcean takes
# a daily backup with 7 days of point-in-time restore. The nightly restic
# dumps to R2 are the off-site copy.

locals {
  db_region = "nyc3"

  # Trusted sources while the data is loaded from the Vultr VM. Removed after
  # the cutover. The apps that use each database (app.tf) are its permanent
  # trusted sources.
  migration_source_ips = ["45.77.154.196"]
}

# --- Fleet: MySQL 8.4 -------------------------------------------------------

resource "digitalocean_database_cluster" "fleet_mysql" {
  name       = "fleet-mysql"
  engine     = "mysql"
  version    = "8.4"
  size       = "db-s-1vcpu-1gb"
  region     = local.db_region
  node_count = 1
  tags       = ["homelab", "fleet"]

  lifecycle {
    prevent_destroy = true
  }
}

# At cluster creation DigitalOcean replaced sql_require_primary_key and
# sql_mode with its own defaults (Phase 3). After the first apply, plan again
# and re-apply if these show drift, before loading any data.
resource "digitalocean_database_mysql_config" "fleet_mysql" {
  cluster_id = digitalocean_database_cluster.fleet_mysql.id
  # Fleet's vulnerability_host_counts table has no primary key.
  sql_require_primary_key = false
  # MySQL 8's default, which Fleet runs on today. DigitalOcean's default adds
  # ANSI, which makes " quote identifiers.
  sql_mode = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
  # The Fleet dump has rows larger than the 16 MB default.
  max_allowed_packet = 67108864
}

resource "digitalocean_database_db" "fleet" {
  cluster_id = digitalocean_database_cluster.fleet_mysql.id
  name       = "fleet"
}

resource "digitalocean_database_user" "fleet" {
  cluster_id = digitalocean_database_cluster.fleet_mysql.id
  name       = "fleet"

  # The provider reports an empty settings block as drift.
  lifecycle {
    ignore_changes = [settings]
  }
}

resource "digitalocean_database_firewall" "fleet_mysql" {
  cluster_id = digitalocean_database_cluster.fleet_mysql.id

  rule {
    type  = "app"
    value = digitalocean_app.fleet.id
  }

  rule {
    type  = "app"
    value = digitalocean_app.backups.id
  }

  dynamic "rule" {
    for_each = local.migration_source_ips
    content {
      type  = "ip_addr"
      value = rule.value
    }
  }
}

# --- Authentik: PostgreSQL 17 -----------------------------------------------

resource "digitalocean_database_cluster" "authentik_pg" {
  name       = "authentik-pg"
  engine     = "pg"
  version    = "17"
  size       = "db-s-1vcpu-1gb"
  region     = local.db_region
  node_count = 1
  tags       = ["homelab", "authentik"]

  lifecycle {
    prevent_destroy = true
  }
}

# The database belongs to doadmin. Before the first restore, doadmin grants
# the authentik user CREATE on the database and on schema public (see the
# runbook in do/README.md).
resource "digitalocean_database_db" "authentik" {
  cluster_id = digitalocean_database_cluster.authentik_pg.id
  name       = "authentik"
}

resource "digitalocean_database_user" "authentik" {
  cluster_id = digitalocean_database_cluster.authentik_pg.id
  name       = "authentik"

  # The provider reports an empty settings block as drift.
  lifecycle {
    ignore_changes = [settings]
  }
}

resource "digitalocean_database_firewall" "authentik_pg" {
  cluster_id = digitalocean_database_cluster.authentik_pg.id

  rule {
    type  = "app"
    value = digitalocean_app.authentik.id
  }

  rule {
    type  = "app"
    value = digitalocean_app.backups.id
  }

  dynamic "rule" {
    for_each = local.migration_source_ips
    content {
      type  = "ip_addr"
      value = rule.value
    }
  }
}
