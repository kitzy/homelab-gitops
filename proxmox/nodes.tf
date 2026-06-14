# Cluster discovery — read-only, verifies connectivity and captures node names.
data "proxmox_virtual_environment_nodes" "all" {}

output "cluster_nodes" {
  description = "Names of all PVE nodes in the cluster."
  value       = data.proxmox_virtual_environment_nodes.all.names
}
