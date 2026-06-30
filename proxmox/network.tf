resource "proxmox_network_linux_bridge" "pve1_vmbr0" {
  address        = "10.253.1.201/24"
  address6       = null
  autostart      = true
  comment        = null
  gateway        = "10.253.1.1"
  gateway6       = null
  mtu            = null
  name           = "vmbr0"
  node_name      = "pve1"
  ports          = ["enp5s0"]
  timeout_reload = 100
  vids           = null
  vlan_aware     = false
}

resource "proxmox_network_linux_bridge" "pve1_vmbr1" {
  address        = "10.253.20.21/24"
  address6       = null
  autostart      = true
  comment        = null
  gateway        = "10.253.20.1"
  gateway6       = null
  mtu            = null
  name           = "vmbr1"
  node_name      = "pve1"
  ports          = ["bond0"]
  timeout_reload = 100
  vids           = null
  vlan_aware     = false
}

resource "proxmox_network_linux_bridge" "pve2_vmbr0" {
  address        = "10.253.1.202/24"
  address6       = null
  autostart      = true
  comment        = null
  gateway        = "10.253.1.1"
  gateway6       = null
  mtu            = null
  name           = "vmbr0"
  node_name      = "pve2"
  ports          = ["enp5s0"]
  timeout_reload = 100
  vids           = null
  vlan_aware     = false
}

resource "proxmox_network_linux_bridge" "pve2_vmbr1" {
  address        = "10.253.20.22/24"
  address6       = null
  autostart      = true
  comment        = null
  gateway        = "10.253.20.1"
  gateway6       = null
  mtu            = null
  name           = "vmbr1"
  node_name      = "pve2"
  ports          = ["bond0"]
  timeout_reload = 100
  vids           = null
  vlan_aware     = false
}
