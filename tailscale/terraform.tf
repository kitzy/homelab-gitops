terraform {
  required_version = ">= 1.9"

  # State + runs are managed by HCP Terraform (Terraform Cloud), VCS-driven.
  # The workspace below must exist and be connected to this repo with:
  #   - Working Directory: tailscale
  #   - VCS trigger paths:  tailscale/**
  # so PRs get a speculative plan and merges to main apply. See README.md.
  #
  # NOTE: set `organization` to your actual HCP organization name.
  cloud {
    organization = "kitzy"

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
