terraform {
  required_version = ">= 1.6"

  # HCP Terraform holds remote state only. The workspace (homelab-google) runs
  # in local execution mode: GitHub Actions is the runner.
  cloud {
    organization = "kitzy_net"

    workspaces {
      name = "homelab-google"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.12"
    }
  }
}
