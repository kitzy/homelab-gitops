terraform {
  required_version = ">= 1.6"

  # HCP Terraform holds remote state only. The workspace runs in local
  # execution mode: GitHub Actions is the runner and HCP stores the state file.
  # The workspace must exist and use Execution Mode: Local, with no VCS
  # connection. See ../README.md.
  cloud {
    organization = "kitzy_net"

    workspaces {
      name = "homelab-vps"
    }
  }

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.33"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.30"
    }
  }
}
