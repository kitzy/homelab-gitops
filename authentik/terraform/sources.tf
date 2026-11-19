# Identity sources: Google OAuth sign-in, and Google Workspace LDAP for
# users and groups.

resource "authentik_source_oauth" "google" {
  access_token_url               = "https://oauth2.googleapis.com/token"
  authentication_flow            = data.authentik_flow.default_source_authentication.id
  authorization_code_auth_method = "basic_auth"
  authorization_url              = "https://accounts.google.com/o/oauth2/v2/auth"
  consumer_key                   = "594904182820-ebp8r1cr1ac5vtdp9781kdce3ib2q8d0.apps.googleusercontent.com"
  consumer_secret                = var.google_oauth_client_secret
  enabled                        = true
  enrollment_flow                = data.authentik_flow.default_source_enrollment.id
  group_matching_mode            = "identifier"
  name                           = "Google"
  oidc_jwks = jsonencode({
    keys = [{
      alg = "RS256"
      e   = "AQAB"
      kid = "943a3a5d7d919625a454e489b75c29adab57acba"
      kty = "RSA"
      n   = "pIpnzA2ezyEERJSxiqpLBmMeIqATH-V6iuBtKIibXEyYovujrx8niqTeO6RIyXT6uDUUv0V2kJ8V_iWYFxzXY1BqK9IfcAmjg0XUDoyTVkoyLsF0gj299LH-zw5vCvy8jmamFIZKAbKcQ5hpHvSittM1vl-6vVL-i2GxyGbMA9aY6Hq15NylS1t7ELTYfQimlnvxcb7_DM0cuS5U1SfbCZMCpKhh0nrSlYds240oxpCJOV2rBahs_Ea5c7tezS1nwVC9W_E-bR9TF6BHkC_fv-E8DcWfkI_6geaJzBhINNxBfjx-w1-WUp2Jz3YYFWEfeQjxMqu-Fg6cGxwk7V16uQ"
      use = "sig"
      }, {
      alg = "RS256"
      e   = "AQAB"
      kid = "9e7b714e8bfb4ef03bac2570eb322bfb7d686ee9"
      kty = "RSA"
      n   = "7O_xgke58DhpSDJRmIMm-u4fcgxyybcqhkKLHesjVvRuhcxYWFUDkb4elTCgEZGH35JXHK0BDZzA1IDuNdum6wnHFC9emCtE0j781ZPVdpK40qBB_tCk05iJrBaeL92Ep4AznwgCUI0ETQkZHnRcHDn2u-XDlABu1a9nfi3ZNL-JYZEBioielRWvIST64Q7EADp8VglvLQTTNcIYXYSoySBlI4YLipMwJYlw49Skac2IunodvJB6z8Z8VcZKvM87uC00CZMfi6ZuIN7Qjval66BIgamM4sJ6W6aUHDFfCiDOuEQtsXo5ItWg70fItLeTpss1_pJdxkM0nzfx6ccmQQ"
      use = "sig"
    }]
  })
  oidc_jwks_url           = "https://www.googleapis.com/oauth2/v3/certs"
  pkce                    = "none"
  policy_engine_mode      = "any"
  profile_url             = "https://openidconnect.googleapis.com/v1/userinfo"
  promoted                = false
  property_mappings       = []
  property_mappings_group = []
  provider_type           = "google"
  slug                    = "google"
  user_matching_mode      = "email_deny"
  user_path_template      = "goauthentik.io/sources/%(slug)s"
  uuid                    = "b3aceb3b-5a82-41ab-8661-600aa9aac871"
}

resource "authentik_source_ldap" "google_ldap" {
  base_dn                                 = "dc=kitzy,dc=com"
  bind_cn                                 = "Cooperativ"
  bind_password                           = var.google_ldap_bind_password
  delete_not_found_objects                = false
  enabled                                 = true
  group_membership_field                  = "member"
  group_object_filter                     = "(objectClass= groupOfNames)"
  lookup_groups_from_user                 = false
  name                                    = "Google LDAP"
  object_uniqueness_field                 = "objectSid"
  password_login_update_internal_password = false
  property_mappings                       = [authentik_property_mapping_source_ldap.google_ldap_mail_to_email.id, authentik_property_mapping_source_ldap.google_ldap_objectsid_to_ldap_uniq.id, authentik_property_mapping_source_ldap.google_ldap_mail_to_username.id, authentik_property_mapping_source_ldap.google_ldap_sn_to_familyname.id, authentik_property_mapping_source_ldap.google_ldap_displayname_to_name.id, authentik_property_mapping_source_ldap.google_ldap_givenname_to_givenname.id]
  property_mappings_group                 = [authentik_property_mapping_source_ldap.google_ldap_displayname_to_name__group.id, authentik_property_mapping_source_ldap.google_ldap_objectsid_to_ldap_uniq__group.id]
  server_uri                              = "ldap://ldap.google.com"
  slug                                    = "google-ldap"
  sni                                     = false
  start_tls                               = true
  sync_groups                             = true
  sync_outgoing_trigger_mode              = "deferred_end"
  sync_users                              = true
  sync_users_password                     = false
  user_membership_attribute               = "distinguishedName"
  user_object_filter                      = "(objectClass=person)"
  user_path_template                      = "goauthentik.io/sources/%(slug)s"
  uuid                                    = "3b56d0c3-3a25-4114-823b-c097f1b81d67"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_displayname_to_name" {
  expression = "return {\n    \"name\": list_flatten(ldap.get(\"displayName\")),\n}"
  name       = "Google LDAP displayName > name"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_displayname_to_name__group" {
  expression = "return {\n    \"name\": list_flatten(ldap.get(\"displayName\")),\n}"
  name       = "Google LDAP displayName > name (group)"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_givenname_to_givenname" {
  expression = "return {\n    \"attributes\": {\n        \"givenName\": list_flatten(ldap.get(\"givenName\")),\n    },\n}"
  name       = "Google LDAP givenName > givenName"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_mail_to_email" {
  expression = "return {\n    \"email\": list_flatten(ldap.get(\"mail\")),\n}"
  name       = "Google LDAP mail > email"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_mail_to_username" {
  expression = "return {\n    \"username\": list_flatten(ldap.get(\"mail\")),\n}"
  name       = "Google LDAP mail > username"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_objectsid_to_ldap_uniq" {
  expression = "return {\n    \"attributes\": {\n        \"ldap_uniq\": list_flatten(ldap.get(\"objectSid\")),\n    },\n}"
  name       = "Google LDAP objectSid > ldap_uniq"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_objectsid_to_ldap_uniq__group" {
  expression = "return {\n    \"attributes\": {\n        \"ldap_uniq\": list_flatten(ldap.get(\"objectSid\")),\n    },\n}"
  name       = "Google LDAP objectSid > ldap_uniq (group)"
}

resource "authentik_property_mapping_source_ldap" "google_ldap_sn_to_familyname" {
  expression = "return {\n    \"attributes\": {\n        \"familyName\": list_flatten(ldap.get(\"sn\")),\n    },\n}"
  name       = "Google LDAP sn > familyName"
}
