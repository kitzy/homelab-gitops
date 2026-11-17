provider "vultr" {
  # Reads the API key from VULTR_API_KEY. CI loads it from 1Password
  # (see .github/workflows/vps-terraform.yaml).
  rate_limit  = 700
  retry_limit = 3
}

provider "tailscale" {
  # OAuth client credentials come from TAILSCALE_OAUTH_CLIENT_ID and
  # TAILSCALE_OAUTH_CLIENT_SECRET, the same client the tailscale/ root uses.
  # It needs the auth_keys write scope to mint the bootstrap key.
  tailnet = "-"
}
