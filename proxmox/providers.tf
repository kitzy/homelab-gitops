provider "proxmox" {
  # Auth comes from environment variables set by CI from 1Password
  # (see .github/workflows/proxmox-terraform.yaml):
  #   PROXMOX_VE_ENDPOINT  — e.g. "https://pve.yourtailnet.ts.net:8006/"
  #   PROXMOX_VE_API_TOKEN — "user@pam!token-id=secret"
  #   PROXMOX_VE_INSECURE  — "true" for self-signed certs

  # Uncomment if you need SSH for ISO uploads or node-level file operations:
  # ssh {
  #   agent    = false
  #   username = "root"
  # }
}
