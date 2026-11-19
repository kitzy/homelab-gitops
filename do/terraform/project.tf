# DigitalOcean project for everything in this root. It is the account's
# default project (created as "first-project"), imported and renamed.

import {
  to = digitalocean_project.homelab
  id = "65cdb5f5-9881-4399-b5a5-237b1f4787f1"
}

resource "digitalocean_project" "homelab" {
  name        = "homelab"
  description = "Homelab services: Fleet and backups (kitzy/homelab-gitops do/terraform)"
  purpose     = "Service or API"
  environment = "Production"
  is_default  = true

  resources = [
    digitalocean_app.fleet.urn,
    digitalocean_app.backups.urn,
    digitalocean_database_cluster.fleet_mysql.urn,
  ]
}
