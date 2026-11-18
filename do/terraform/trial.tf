# Phase 3 of the DigitalOcean migration: a short-lived MySQL 8.4 cluster to
# prove Fleet runs on DigitalOcean's managed MySQL before anything else is
# built. Removed by a follow-up PR once the checks are done (a few dollars).
#
# Checks:
#   1. sql_require_primary_key = false takes effect (Fleet's
#      vulnerability_host_counts table has no primary key).
#   2. sql_mode matches MySQL's default, which Fleet runs on today.
#      DigitalOcean's default adds ANSI, which makes " quote identifiers.
#   3. Last night's Fleet dump loads, and `fleet prepare db` (v4.95.0)
#      succeeds on 8.4.
#   4. A restore from DigitalOcean's own backup works despite the table
#      without a primary key.

resource "digitalocean_database_cluster" "fleet_mysql_trial" {
  name       = "fleet-mysql-trial"
  engine     = "mysql"
  version    = "8.4"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1
  tags       = ["homelab", "trial"]
}

resource "digitalocean_database_mysql_config" "fleet_mysql_trial" {
  cluster_id              = digitalocean_database_cluster.fleet_mysql_trial.id
  sql_require_primary_key = false
  # MySQL 8's default sql_mode, the same as the Vultr VM runs today.
  sql_mode = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
  # Fleet's mysqldump has rows larger than the 16 MB default; the VM uses 64 MB.
  max_allowed_packet = 67108864
}

resource "digitalocean_database_db" "fleet_trial" {
  cluster_id = digitalocean_database_cluster.fleet_mysql_trial.id
  name       = "fleet"
}

# Only the Vultr VM may connect: the dump is loaded from there.
resource "digitalocean_database_firewall" "fleet_mysql_trial" {
  cluster_id = digitalocean_database_cluster.fleet_mysql_trial.id

  rule {
    type  = "ip_addr"
    value = "45.77.154.196"
  }
}
