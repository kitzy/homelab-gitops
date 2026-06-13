terraform {
  required_version = ">= 1.0"

  # HCP Terraform (Terraform Cloud) holds remote state only. The workspace runs
  # in *local execution* mode (matching kitzy/dns) — GitHub Actions is the
  # runner; HCP just stores the state file. The workspace must exist and use
  # Execution Mode: Local, with no VCS connection. See README.md.
  cloud {
    organization = "kitzy_net"

    workspaces {
      name = "homelab-tailscale"
    }
  }

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}
