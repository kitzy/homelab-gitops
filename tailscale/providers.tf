provider "tailscale" {
  # Authentication comes from OAuth client credentials, which the provider reads
  # automatically from these environment variables. CI sets them on the job from
  # 1Password (see .github/workflows/tailscale-terraform.yaml):
  #   TAILSCALE_OAUTH_CLIENT_ID
  #   TAILSCALE_OAUTH_CLIENT_SECRET
  #
  # "-" resolves to the OAuth client's own tailnet, so nothing tailnet-specific
  # is hardcoded here. Override with TAILSCALE_TAILNET if you ever need to pin it.
  tailnet = "-"
}
