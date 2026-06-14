terraform {
  required_version = ">= 1.0"

  # HCP Terraform holds remote state only. Workspace runs in local execution mode —
  # GitHub Actions is the runner. Create the workspace with Execution Mode: Local,
  # no VCS connection. See .github/workflows/proxmox-terraform.yaml.
  cloud {
    organization = "kitzy_net"

    workspaces {
      name = "homelab-proxmox"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.109"
    }
  }
}
