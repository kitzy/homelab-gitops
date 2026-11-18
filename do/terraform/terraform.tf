terraform {
  required_version = ">= 1.6"

  # HCP Terraform holds remote state only. The workspace runs in local
  # execution mode: GitHub Actions is the runner and HCP stores the state file.
  # The workspace (homelab-do) exists with Execution Mode: Local and no VCS
  # connection.
  cloud {
    organization = "kitzy_net"

    workspaces {
      name = "homelab-do"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.29"
    }
  }
}
