provider "tailscale" {
  # Authentication is supplied as sensitive environment variables on the HCP
  # workspace; the provider reads them automatically:
  #   TAILSCALE_OAUTH_CLIENT_ID
  #   TAILSCALE_OAUTH_CLIENT_SECRET
  #
  # "-" resolves to the OAuth client's own tailnet, so nothing tailnet-specific
  # is hardcoded here. Override with TAILSCALE_TAILNET if you ever need to pin it.
  tailnet = "-"
}
