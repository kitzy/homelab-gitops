output "instance_id" {
  description = "Vultr instance ID."
  value       = vultr_instance.vps.id
}

output "public_ipv4" {
  description = "Public IPv4. No inbound ports are open. Use Tailscale (homelab-vps) to reach the VM."
  value       = vultr_instance.vps.main_ip
}

output "public_ipv6" {
  description = "Public IPv6. No inbound ports are open."
  value       = vultr_instance.vps.v6_main_ip
}
