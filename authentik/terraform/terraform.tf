terraform {
  required_version = ">= 1.6"

  # HCP Terraform holds remote state only. The workspace (homelab-authentik)
  # runs in local execution mode: GitHub Actions is the runner.
  cloud {
    organization = "kitzy_net"

    workspaces {
      name = "homelab-authentik"
    }
  }

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8"
    }
  }
}
