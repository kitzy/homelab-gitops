data "vultr_os" "ubuntu" {
  filter {
    name   = "name"
    values = [var.os_name]
  }
}

# Inbound: only Tailscale's direct-connection port. Egress is open. Admin
# access is Tailscale SSH and public traffic arrives through the Cloudflare
# Tunnel, both outbound connections.
#
# A Vultr firewall group with NO rules allows everything (found 2026-11-17:
# public port 22 was reachable). It drops unmatched traffic only once it has
# at least one rule, so these rules are what make the group default-deny.
resource "vultr_firewall_group" "vps" {
  description = "${var.hostname}: no inbound"
}

# UDP 41641 lets Tailscale peers connect directly instead of through a DERP
# relay. Tailscale traffic is authenticated and encrypted end to end.
resource "vultr_firewall_rule" "tailscale_v4" {
  firewall_group_id = vultr_firewall_group.vps.id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "41641"
  notes             = "Tailscale direct connections"
}

resource "vultr_firewall_rule" "tailscale_v6" {
  firewall_group_id = vultr_firewall_group.vps.id
  protocol          = "udp"
  ip_type           = "v6"
  subnet            = "::"
  subnet_size       = 0
  port              = "41641"
  notes             = "Tailscale direct connections"
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
