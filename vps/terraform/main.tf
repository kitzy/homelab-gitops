# Decommissioned 2026-11-19. The homelab moved to DigitalOcean (do/); this
# root keeps only its backend and providers so that the apply destroys the
# Vultr VM, its block storage, its firewall group and the Tailscale key.
# A follow-up PR removes vps/terraform entirely.
