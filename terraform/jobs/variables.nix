# Platform configuration (Consul, Vault, Nomad)
# This will be applied automatically by the GitHub Actions runner
{ globals, ... }:
{

  # Variables needed from secrets
  variable = {
    domain = {
      type = "string";
      description = "Domain name";
      default = "${globals.domains.main}";
    };

    nomad_url = {
      type = "string";
      description = "Nomad URL";
      default = "https://nomad.local.${globals.domains.main}";
    };

    authelia_oidc_client_secret = {
      type = "string";
      description = "OIDC client secret for Vault Authelia integration";
      sensitive = true;
    };

    nomad_oidc_client_secret = {
      type = "string";
      description = "OIDC client secret for Nomad Authelia integration";
      sensitive = true;
    };

    consul_bootstrap_token = {
      type = "string";
      description = "Consul bootstrap token for Vault Consul secrets engine";
      sensitive = true;
    };
  };
}
