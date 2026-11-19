# Fleet: SAML single sign-on for admins (fleet.kitzy.net) and SCIM user
# provisioning into Fleet.

resource "authentik_application" "fleet_admin" {
  backchannel_providers = []
  meta_hide             = false
  meta_icon             = "fleet-logo-mark-rgb.png"
  name                  = "Fleet (Admin)"
  open_in_new_tab       = true
  policy_engine_mode    = "any"
  protocol_provider     = authentik_provider_saml.fleet_admin.id
  slug                  = "fleet-admin"
  uuid                  = "f021a2ae-2607-41b5-93b9-63c5d2ef616a"
}

resource "authentik_application" "fleet_scim_app" {
  backchannel_providers = [authentik_provider_scim.fleet_scim.id]
  meta_hide             = false
  meta_icon             = "fleet-logo-mark-rgb.png"
  name                  = "Fleet SCIM App"
  open_in_new_tab       = false
  policy_engine_mode    = "any"
  protocol_provider     = authentik_provider_scim.fleet_scim.id
  slug                  = "fleet-scim-app"
  uuid                  = "1c037048-90dd-4c69-8733-a77ae69f87aa"
}

resource "authentik_provider_saml" "fleet_admin" {
  acs_url                         = "https://fleet.kitzy.net/api/v1/fleet/sso/callback"
  assertion_valid_not_before      = "minutes=-5"
  assertion_valid_not_on_or_after = "minutes=5"
  audience                        = "https://fleet.kitzy.net"
  authorization_flow              = data.authentik_flow.default_provider_authorization_implicit_consent.id
  default_name_id_policy          = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
  digest_algorithm                = "http://www.w3.org/2001/04/xmlenc#sha256"
  invalidation_flow               = data.authentik_flow.default_provider_invalidation_flow.id
  issuer_override                 = "authentik"
  logout_method                   = "frontchannel_iframe"
  name                            = "Provider for Fleet (Admin)"
  name_id_mapping                 = data.authentik_property_mapping_provider_saml.provider_saml_email.id
  property_mappings               = [data.authentik_property_mapping_provider_saml.provider_saml_upn.id, data.authentik_property_mapping_provider_saml.provider_saml_name.id, data.authentik_property_mapping_provider_saml.provider_saml_email.id, data.authentik_property_mapping_provider_saml.provider_saml_username.id, data.authentik_property_mapping_provider_saml.provider_saml_uid.id, data.authentik_property_mapping_provider_saml.provider_saml_groups.id, data.authentik_property_mapping_provider_saml.provider_saml_ms_windowsaccountname.id]
  session_valid_not_on_or_after   = "minutes=86400"
  sign_assertion                  = true
  sign_logout_request             = false
  sign_logout_response            = false
  sign_response                   = true
  signature_algorithm             = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
  signing_kp                      = data.authentik_certificate_key_pair.saml_signing.id
  sls_binding                     = "redirect"
  sp_binding                      = "post"
  url_slo_post                    = "https://auth.kitzy.net/application/saml/fleet-admin/slo/binding/post/"
  url_slo_redirect                = "https://auth.kitzy.net/application/saml/fleet-admin/slo/binding/redirect/"
  url_sso_init                    = "https://auth.kitzy.net/application/saml/fleet-admin/sso/binding/init/"
  url_sso_post                    = "https://auth.kitzy.net/application/saml/fleet-admin/sso/binding/post/"
  url_sso_redirect                = "https://auth.kitzy.net/application/saml/fleet-admin/sso/binding/redirect/"
}

resource "authentik_provider_scim" "fleet_scim" {
  auth_mode                             = "token"
  auth_oauth_params                     = jsonencode({})
  compatibility_mode                    = "default"
  dry_run                               = false
  exclude_users_service_account         = true
  group_filters                         = []
  name                                  = "Fleet SCIM Provider"
  property_mappings                     = [data.authentik_property_mapping_provider_scim.provider_scim_user.id]
  property_mappings_group               = [data.authentik_property_mapping_provider_scim.provider_scim_group.id]
  service_provider_config_cache_timeout = "hours=1"
  sync_page_size                        = 100
  sync_page_timeout                     = "minutes=30"
  token                                 = var.fleet_scim_token
  url                                   = "https://fleet.kitzy.net/api/v1/fleet/scim"
}
