{
  config,
  lib,
  nodes,
  globals,
  ...
}:
{

  # environment.persistence."/state".directories = [
  #   {
  #     directory = "/var/lib/private/ollama";
  #     mode = "0700";
  #   }
  #   {
  #     directory = "/var/lib/private/open-webui";
  #     mode = "0700";
  #   }
  # ];

  age.secrets.open-webui-env = {
    generator.dependencies = [ nodes.zeus-auth.config.age.secrets.open-webui-oidc-client-secret ];
    generator.script = lib.helpers.generateWithEnv "OAUTH_CLIENT_SECRET";
  };

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 11222;
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";

      ENABLE_COMMUNITY_SHARING = "False";
      ENABLE_ADMIN_EXPORT = "False";

      OLLAMA_BASE_URL = "http://localhost:11434";
      TRANSFORMERS_CACHE = "/var/lib/open-webui/.cache/huggingface";

      WEBUI_URL = "https://chat.${globals.domains.main}";
      ENABLE_OAUTH_SIGNUP = "true";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "true";
      OAUTH_CLIENT_ID = "open-webui";
      OPENID_PROVIDER_URL = "https://auth.${globals.domains.main}/.well-known/openid-configuration";
      OAUTH_PROVIDER_NAME = "Authelia";
      OAUTH_SCOPES = "openid email profile groups";
      ENABLE_OAUTH_ROLE_MANAGEMENT = "true";
      OAUTH_ALLOWED_ROLES = "openwebui,openwebui-admin";
      OAUTH_ADMIN_ROLES = "openwebui-admin";
      OAUTH_ROLES_CLAIM = "groups";
    };

    environmentFile = config.age.secrets.open-webui-env.path;
  };

  consul.services.open-webui = {
    port = 11222;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.open-webui.rule=Host(`chat.${globals.domains.main}`)"
      "traefik.http.routers.open-webui.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.orpheus.firewall.inbound = [
    {
      port = "11434";
      proto = "tcp";
      host = "any";
    }
    {
      port = "11222";
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
