{
  config,
  globals,
  nodes,
  nomadCfg,
  ...
}:
{

  age.secrets.grafana-secret-key = {
    rekeyFile = config.node.secretsDir + "/grafana-secret-key.age";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-loki-basic-auth-password = {
    generator.script = "alnum";
    mode = "440";
    group = "grafana";
  };

  globals.loki-secrets = [ config.age.secrets.grafana-loki-basic-auth-password ];

  # Mirror the original oidc secret
  age.secrets.grafana-oidc-client-secret = {
    inherit (nomadCfg.config.age.secrets.authelia-grafana-oidc-client-secret) rekeyFile;
    mode = "440";
    group = "grafana";
  };

  environment.persistence."/persist".directories = [
    {
      directory = config.services.grafana.dataDir;
      user = "grafana";
      group = "grafana";
      mode = "0700";
    }
  ];

  services.grafana = {
    enable = true;
    settings = {
      analytics.reporting_enabled = false;
      users.allow_sign_up = false;

      server = {
        domain = "grafana.local.${globals.domains.main}";
        root_url = "https://grafana.local.${globals.domains.main}";
        enforce_domain = true;
        enable_gzip = true;
        http_addr = globals.nebula.mesh.hosts.zeus-grafana.ipv4;
        http_port = 3001;
      };

      security = {
        disable_initial_admin_creation = true;
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
        cookie_secure = true;
        disable_gravatar = true;
        hide_version = true;
      };

      auth.disable_login_form = true;
      "auth.generic_oauth" = {
        enabled = true;
        name = "Authelia";
        icon = "signin";
        allow_sign_up = true;
        client_id = "grafana";
        client_secret = "$__file{${config.age.secrets.grafana-oidc-client-secret.path}}";
        scopes = "openid profile email groups";
        empty_scopes = false;
        login_attribute_path = "preferred_username";
        groups_attribute_path = "groups";
        auth_url = "https://auth.${globals.domains.main}/api/oidc/authorization";
        token_url = "https://auth.${globals.domains.main}/api/oidc/token";
        api_url = "https://auth.${globals.domains.main}/api/oidc/userinfo";
        use_pkce = true;
        # Allow mapping oidc roles to server admin
        allow_assign_grafana_admin = true;
        role_attribute_path = "contains(groups[*], 'server_admin') && 'GrafanaAdmin' || contains(groups[*], 'admin') && 'Admin' || contains(groups[*], 'editor') && 'Editor' || contains(groups[*], 'viewer') && 'Viewer'";
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Loki";
          type = "loki";
          access = "direct";
          url = "http://${globals.nebula.mesh.hosts.zeus-loki.ipv4}";
          orgId = 1;
          basicAuth = true;
          basicAuthUser = "${config.node.name}+grafana-loki-basic-auth-password";
          secureJsonData.basicAuthPassword = "$__file{${config.age.secrets.grafana-loki-basic-auth-password.path}}";
        }
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://${globals.nebula.mesh.hosts.zeus-prometheus.ipv4}:${builtins.toString nodes.zeus-prometheus.config.services.prometheus.port}";
          jsonData.timeInterval = "60s";
        }
      ];
    };
  };

  globals.monitoring.http.grafana = {
    url = "https://grafana.local.${globals.domains.main}/api/health";
    expectedBodyRegex = "ok";
    network = "internal";
  };

  consul.services.grafana = {
    port = 3001;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.grafana.rule=Host(`grafana.local.${globals.domains.main}`)"
    ];
  };

  globals.nebula.mesh.hosts.zeus-grafana.firewall.inbound = [
    {
      port = "3001";
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
