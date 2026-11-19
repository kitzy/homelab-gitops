# Authentik's built-in objects that the managed config refers to. They come
# from Authentik's own blueprints and are not managed here.

data "authentik_certificate_key_pair" "saml_signing" {
  name = "saml-signing"
}

data "authentik_flow" "default_invalidation_flow" {
  slug = "default-invalidation-flow"
}

data "authentik_flow" "default_provider_authorization_implicit_consent" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_provider_invalidation_flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_flow" "default_source_authentication" {
  slug = "default-source-authentication"
}

data "authentik_flow" "default_source_enrollment" {
  slug = "default-source-enrollment"
}

data "authentik_flow" "default_user_settings_flow" {
  slug = "default-user-settings-flow"
}

data "authentik_property_mapping_provider_saml" "provider_saml_email" {
  managed = "goauthentik.io/providers/saml/email"
}

data "authentik_property_mapping_provider_saml" "provider_saml_groups" {
  managed = "goauthentik.io/providers/saml/groups"
}

data "authentik_property_mapping_provider_saml" "provider_saml_ms_windowsaccountname" {
  managed = "goauthentik.io/providers/saml/ms-windowsaccountname"
}

data "authentik_property_mapping_provider_saml" "provider_saml_name" {
  managed = "goauthentik.io/providers/saml/name"
}

data "authentik_property_mapping_provider_saml" "provider_saml_uid" {
  managed = "goauthentik.io/providers/saml/uid"
}

data "authentik_property_mapping_provider_saml" "provider_saml_upn" {
  managed = "goauthentik.io/providers/saml/upn"
}

data "authentik_property_mapping_provider_saml" "provider_saml_username" {
  managed = "goauthentik.io/providers/saml/username"
}

data "authentik_property_mapping_provider_scim" "provider_scim_group" {
  managed = "goauthentik.io/providers/scim/group"
}

data "authentik_property_mapping_provider_scim" "provider_scim_user" {
  managed = "goauthentik.io/providers/scim/user"
}

data "authentik_stage" "default_authenticator_totp_setup" {
  name = "default-authenticator-totp-setup"
}

data "authentik_stage" "default_authenticator_webauthn_setup" {
  name = "default-authenticator-webauthn-setup"
}
