data "vultr_os" "ubuntu" {
  filter {
    name   = "name"
    values = [var.os_name]
  }
}

# No inbound rules. A Vultr firewall group with no rules drops all inbound
# traffic. Egress is open. Admin access is Tailscale SSH and public traffic
# arrives through the Cloudflare Tunnel, both outbound connections.
resource "vultr_firewall_group" "vps" {
  description = "${var.hostname}: no inbound"
}

# Single-use, pre-authorized key that joins the VM to the tailnet as tag:vps.
# It is only read by cloud-init on first boot. Later expiry does not matter
# because the node key persists on the VM.
resource "tailscale_tailnet_key" "vps" {
  reusable            = false
  ephemeral           = false
  preauthorized       = true
  expiry              = 3600
  tags                = ["tag:vps"]
  description         = "${var.hostname} bootstrap"
  recreate_if_invalid = "never"
}

resource "vultr_instance" "vps" {
  label             = var.hostname
  hostname          = var.hostname
  region            = var.region
  plan              = var.plan
  os_id             = data.vultr_os.ubuntu.id
  firewall_group_id = vultr_firewall_group.vps.id
  enable_ipv6       = true
  activation_email  = false
  ddos_protection   = false
  tags              = ["homelab"]

  backups = var.enable_vultr_backups ? "enabled" : "disabled"
  dynamic "backups_schedule" {
    for_each = var.enable_vultr_backups ? [1] : []
    content {
      type = "daily"
      hour = 9 # UTC, after the nightly restic run
    }
  }

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname           = var.hostname
    tailscale_auth_key = tailscale_tailnet_key.vps.key
    docker_on_volume   = var.docker_volume_size_gb > 0
  })

  lifecycle {
    # Docker volumes (all databases) live on this VM's disk. A replace would
    # destroy them, so Terraform must never do it on its own.
    prevent_destroy = true
    # cloud-init runs only on first boot, so later edits to it (or a re-minted
    # Tailscale key) must not force a replace. Same for a renamed OS image.
    ignore_changes = [user_data, os_id]
  }
}

resource "vultr_block_storage" "docker" {
  count = var.docker_volume_size_gb > 0 ? 1 : 0

  label                = "${var.hostname}-docker"
  region               = var.region
  size_gb              = var.docker_volume_size_gb
  block_type           = "high_perf"
  attached_to_instance = vultr_instance.vps.id
  live                 = true

  lifecycle {
    prevent_destroy = true
  }
}
