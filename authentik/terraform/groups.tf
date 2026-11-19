# Groups. Membership is not managed here.

resource "authentik_group" "authentik_admins" {
  attributes   = jsonencode({})
  is_superuser = true
  name         = "authentik Admins"
  parents      = []
  roles        = []
  users        = [5, 8, 9976]

  # Membership is managed in Authentik (and by the Google LDAP sync).
  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "synology_nas" {
  attributes = jsonencode({
    distinguishedName = "cn=synology-nas,ou=Groups,dc=kitzy,dc=com"
    ldap_uniq         = "S-1-5-21-359790238-951543651-1098909184-1890864143"
  })
  is_superuser = false
  name         = "Synology NAS"
  parents      = []
  roles        = []
  users        = []

  # Membership is managed in Authentik (and by the Google LDAP sync).
  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "test" {
  attributes = jsonencode({
    distinguishedName = "cn=test,ou=Groups,dc=kitzy,dc=com"
    ldap_uniq         = "S-1-5-21-359790238-951543651-2988534303-278350229"
  })
  is_superuser = false
  name         = "test"
  parents      = []
  roles        = []
  users        = []

  # Membership is managed in Authentik (and by the Google LDAP sync).
  lifecycle {
    ignore_changes = [users]
  }
}
