# Tailnet DNS settings.
#
# Captured verbatim from the live tailnet: MagicDNS is enabled, and there are no
# global nameservers, search paths, or split-DNS routes configured. Only the
# meaningful setting — MagicDNS — is managed here; the empty surfaces are left
# unmanaged until they're actually configured (see the README roadmap), at which
# point they get their own resources (tailscale_dns_nameservers,
# tailscale_dns_search_paths, tailscale_dns_split_nameservers).
resource "tailscale_dns_preferences" "homelab" {
  magic_dns = true
}
