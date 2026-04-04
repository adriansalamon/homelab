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
  };
}
