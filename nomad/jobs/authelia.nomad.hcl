job "authelia" {
  type = "service"

  group "authelia" {
    count = 2

    network {
      mode = "cni/flannel"

      port "http" {
        static = 29091
        to     = 9091
      }
    }

    task "authelia" {
      driver = "docker"

      config {
        image = "authelia/authelia:4.39"
        ports = ["http"]
        args = [
          "--config", "/config/configuration.yml",
          "--config", "${NOMAD_SECRETS_DIR}/secrets.yml"
        ]

        volumes = [
          "local/authelia/configuration.yml:/config/configuration.yml",
        ]
      }

      template {
        data = <<EOF
{{ $domain := key "config/domains/main" }}
log:
  level: info

server:
  address: "0.0.0.0:9091"

webauthn:
  enable_passkey_login: true

access_control:
  default_policy: deny
  rules:
    - domain: "*.{{ $domain }}"
      policy: two_factor

session:
  name: authelia_session
  cookies:
    - domain: "{{ $domain }}"
      authelia_url: "https://auth.{{ $domain }}"
  redis:
    host: server.redis.service.consul
    port: 6379
    high_availability:
      sentinel_name: mymaster
      nodes:
{{ range service "sentinel.redis" }}
        - host: '{{ .Address }}'
          port: {{ .Port }}
{{ end }}

storage:
  postgres:
    address: {{ range service "primary.homelab-cluster" }}{{ .Address }}:{{ .Port }}{{ end }}
    database: authelia
    username: authelia

authentication_backend:
  ldap:
    address: "ldap://{{ range service "ldap.lldap" }}{{ .Address }}:{{ .Port }}{{ break }}{{ end }}"
    base_dn: "dc=salamon,dc=xyz"
    implementation: "lldap"
    user: "uid=authelia,ou=people,dc=salamon,dc=xyz"

notifier:
  disable_startup_check: true
  smtp:
    address: "smtp://email-smtp.eu-west-1.amazonaws.com:587"
    sender: "Authelia <authelia@{{ $domain }}>"
    timeout: "5s"

identity_providers:
  oidc:
    authorization_policies:
      default:
        default_policy: two_factor
        rules:
          - policy: deny
            subject: "group:lldap_strict_readonly"
{{ with nomadVar "nomad/jobs/authelia" }}
    clients:
      - client_id: "xcz7Bm8a5EC-fDtgd2WPFhX7raI0H2ZcQZww7PmmyRsa8cfvUuNQUz2HRtkNXflqooHwmHAe"
        client_name: "Immich"
        client_secret: {{ .immich_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        redirect_uris:
          - "app.immich:///oauth-callback"
          - "https://immich.{{ $domain }}/auth/login"
          - "https://immich.{{ $domain }}/user-settings"
        scopes:
          - openid
          - profile
          - email
        token_endpoint_auth_method: client_secret_post
        userinfo_signed_response_alg: "none"

      - client_id: "3GATim_TL9yrNLsWhrC9mv0L-44zmv44qDu1EH8ZoXZVdGDrLaQYjjRO49Y66AKGDfzmS6yt"
        client_name: "Jellyfin"
        client_secret: {{ .jellyfin_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        require_pkce: true
        pkce_challenge_method: "S256"
        redirect_uris:
          - "https://jellyfin.{{ $domain }}/sso/OID/redirect/authelia"
        scopes:
          - openid
          - profile
          - email
          - groups
        userinfo_signed_response_alg: "none"
        token_endpoint_auth_method: client_secret_post

      - client_id: "M47wLZwSUPGuGEqeU172pz8eJ6zSPb1aDuZ-h0Y1z9JCEsb-eC27K6UzBuGLSCPF8Am-XpUF"
        client_name: "Tailscale"
        client_secret: {{ .tailscale_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        redirect_uris:
          - "https://login.tailscale.com/a/oauth_response"
        scopes:
          - openid
          - email
          - profile
        userinfo_signed_response_alg: "none"
        token_endpoint_auth_method: client_secret_basic

      - client_id: "headscale"
        client_name: "Headscale"
        client_secret: {{ .headscale_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        redirect_uris:
          - "https://headscale.{{ $domain }}/oidc/callback"
        scopes:
          - openid
          - email
          - profile
          - groups
        userinfo_signed_response_alg: "none"
        token_endpoint_auth_method: client_secret_post

      - client_id: "paperless"
        client_name: "Paperless"
        client_secret: {{ .paperless_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        redirect_uris:
          - "https://paperless.local.{{ $domain }}/accounts/oidc/authelia/login/callback/"
        scopes:
          - openid
          - groups
          - email
          - profile
        userinfo_signed_response_alg: "none"

      - client_id: "grafana"
        client_name: "Grafana"
        client_secret: {{ .grafana_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        redirect_uris:
          - "https://grafana.local.{{ $domain }}/login/generic_oauth"
        scopes:
          - openid
          - groups
          - email
          - profile
        userinfo_signed_response_alg: "none"

      - client_id: "open-webui"
        client_name: "Open WebUI"
        client_secret: {{ .open_webui_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        require_pkce: false
        redirect_uris:
          - "https://chat.{{ $domain }}/oauth/oidc/callback"
        scopes:
          - openid
          - profile
          - groups
          - email
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: "none"
        userinfo_signed_response_alg: "none"
        token_endpoint_auth_method: client_secret_basic

      - client_id: "forgejo"
        client_name: "Forgejo"
        client_secret: {{ .forgejo_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        require_pkce: true
        pkce_challenge_method: "S256"
        redirect_uris:
          - "https://forgejo.{{ $domain }}/user/oauth2/authelia/callback"
        scopes:
          - openid
          - profile
          - email
          - groups
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: "none"
        token_endpoint_auth_method: client_secret_basic

      - client_id: "hass"
        client_name: "Home Assistant"
        client_secret: {{ .hass_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        require_pkce: true
        pkce_challenge_method: "S256"
        authorization_policy: two_factor
        redirect_uris:
          - "https://home-assistant.local.{{ $domain }}/auth/oidc/callback"
        scopes:
          - openid
          - profile
          - groups
        id_token_signed_response_alg: "RS256"
        token_endpoint_auth_method: client_secret_post

      - client_id: "nomad"
        client_name: "Nomad"
        client_secret: {{ .nomad_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        require_pkce: false
        authorization_policy: two_factor
        redirect_uris:
          - "https://nomad.local.{{ $domain }}/ui/settings/tokens"
          - "http://localhost:4649/oidc/callback"
        scopes:
          - openid
          - profile
          - groups
        token_endpoint_auth_method: client_secret_basic

      - client_id: 'linkwarden'
        client_name: 'Linkwarden'
        client_secret: {{ .linkwarden_oidc_client_secret }}
        pre_configured_consent_duration: "3 months"
        public: false
        require_pkce: false
        redirect_uris:
          - 'https://linkwarden.{{ $domain }}/api/v1/auth/callback/authelia'
        scopes:
          - 'openid'
          - 'groups'
          - 'email'
          - 'profile'
        response_types:
          - 'code'
        grant_types:
          - 'authorization_code'
        access_token_signed_response_alg: 'none'
        userinfo_signed_response_alg: 'none'
        token_endpoint_auth_method: 'client_secret_basic'
{{ end }}
EOF

        destination = "local/authelia/configuration.yml"
      }

      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/authelia" }}
{{ .jwks_key }}{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/jwks.pem"
      }

      env {
        X_AUTHELIA_CONFIG_FILTERS = "template"
      }

      template {
        data = <<EOF
{{ with nomadVar "nomad/jobs/authelia" }}
session:
  secret: {{ .session_secret }}
  redis:
    password: {{ .redis_password }}
    high_availability:
      sentinel_password: {{ .redis_sentinel_password }}

storage:
  encryption_key: {{ .storage_encryption_key }}
  postgres:
    password: {{ .postgres_password }}

authentication_backend:
  ldap:
    password: {{ .ldap_password }}

notifier:
  smtp:
    username: {{ .smtp_username }}
    password: {{ .smtp_password }}

identity_validation:
  reset_password:
    jwt_secret: {{ .jwt_secret }}

identity_providers:
  oidc:
    hmac_secret: {{ .hmac_secret }}
    jwks:
      - key: {{ "{{" }} secret "{{ env "NOMAD_SECRETS_DIR" }}/jwks.pem" | mindent 10 "|" | msquote {{ "}}" }}
{{ end }}
EOF

        destination = "${NOMAD_SECRETS_DIR}/secrets.yml"
        perms       = "0600"
      }

      resources {
        cpu    = 250
        memory = 512
      }

      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }

      service {
        port = "http"
        name = "authelia"

        check {
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.external=true",
          "traefik.enable=true",
          "traefik.http.routers.authelia.rule=Host(`auth.${DOMAIN}`)",
          "traefik.http.routers.authelia.entrypoints=websecure",
          "traefik.http.middlewares.authelia.forwardAuth.address=http://authelia.service.consul:29091/api/authz/forward-auth",
          "traefik.http.middlewares.authelia.forwardAuth.trustForwardHeader=true",
          "traefik.http.middlewares.authelia.forwardAuth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email",
        ]
      }
    }
  }
}
