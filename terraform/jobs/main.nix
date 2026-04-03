{ globals, ... }:
{
  # Terraform backend - using Consul KV for state
  terraform.backend.consul = {
    address = "consul.local.${globals.domains.main}";
    scheme = "https";
    path = "terraform/jobs";
  };

  # Required providers
  terraform.required_providers = {
    consul = {
      source = "hashicorp/consul";
      version = "~> 2.0";
    };
    nomad = {
      source = "hashicorp/nomad";
      version = "~> 2.0";
    };
    vault = {
      source = "hashicorp/vault";
      version = "~> 5.0";
    };
  };

  # Provider configurations
  provider = {
    vault = {
      # Will use VAULT_TOKEN from workload identity
      address = "https://vault.local.${globals.domains.main}";
    };

    consul = {
      address = "consul.local.${globals.domains.main}";
      scheme = "https";
    };

    nomad = {
      address = "https://nomad.local.${globals.domains.main}";
      region = "global";
    };
  };
}
