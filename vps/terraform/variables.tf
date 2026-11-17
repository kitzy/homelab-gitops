variable "region" {
  description = "Vultr region. ewr is New Jersey."
  type        = string
  default     = "ewr"
}

variable "plan" {
  description = "Vultr plan ID. vhp-4c-8gb-amd is High Performance, 4 vCPU, 8 GB, 180 GB NVMe, $48/month (looked up with GET /v2/plans?type=vhp). The 16 GB step up is the fallback if memory runs tight."
  type        = string
  default     = "vhp-4c-8gb-amd"
}

variable "os_name" {
  description = "Exact Vultr OS name, resolved to an ID with the vultr_os data source."
  type        = string
  default     = "Ubuntu 24.04 LTS x64"
}

variable "hostname" {
  description = "Hostname of the VM, and its name on the tailnet."
  type        = string
  default     = "homelab-vps"
}

variable "enable_vultr_backups" {
  description = "Turn on Vultr automatic backups (whole-VM snapshots, about 20% of the plan price). Off by default. restic to the Synology is the primary backup."
  type        = bool
  default     = false
}

variable "docker_volume_size_gb" {
  description = "Size of an optional Vultr block storage volume mounted at /var/lib/docker. 0 means none, and Docker uses the VM disk. Only takes effect when the VM is first created, because cloud-init runs once."
  type        = number
  default     = 0
}
