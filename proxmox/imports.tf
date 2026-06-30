# Import blocks for existing PVE resources.
# These were used once to pull live state into HCP Terraform on initial setup.
# After the first successful apply they are inert but safe to leave in place.

# VMs
import {
  to = proxmox_virtual_environment_vm.k3s_control_1
  id = "pve1/101"
}

import {
  to = proxmox_virtual_environment_vm.k3s_control_2
  id = "pve1/102"
}

import {
  to = proxmox_virtual_environment_vm.k3s_control_3
  id = "pve2/103"
}

import {
  to = proxmox_virtual_environment_vm.k3s_worker_1
  id = "pve1/111"
}

import {
  to = proxmox_virtual_environment_vm.k3s_worker_2
  id = "pve2/112"
}

# Network bridges (bonds are not managed by this provider)
import {
  to = proxmox_network_linux_bridge.pve1_vmbr0
  id = "pve1:vmbr0"
}

import {
  to = proxmox_network_linux_bridge.pve1_vmbr1
  id = "pve1:vmbr1"
}

import {
  to = proxmox_network_linux_bridge.pve2_vmbr0
  id = "pve2:vmbr0"
}

import {
  to = proxmox_network_linux_bridge.pve2_vmbr1
  id = "pve2:vmbr1"
}
