job "homepage" {
  group "homepage" {
    count = 1

    network {
      mode = "cni/nebula"
      port "http" {
        static = 17622
      }
    }

    task "homepage" {
      driver = "docker"

      config {
        image = "ghcr.io/adriansalamon/homepage:main-e5c6d46"
        ports = ["http"]
      }

      env {
        ADDR = "${NOMAD_ALLOC_IP_http}:${NOMAD_PORT_http}"
      }

      meta {
        nebula_config = yamlencode({
          firewall = {
            outbound = [
              {
                port  = "any"
                proto = "any"
                host  = "any"
              }
            ]
            inbound = [
              {
                port  = "17622"
                proto = "tcp"
                group = "reverse-proxy"
              }
            ]
          }
        })
      }

      # Service metadata (static, edit to add/remove services)
      template {
        data = <<EOH
# Service metadata configuration

# Productivity & Knowledge
[affine]
name = "AFFiNE"
description = "Knowledge base and workspace"
category = "productivity"
icon_dark = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/affine-light.svg"

[memos]
name = "Memos"
description = "Note-taking and journaling"
category = "productivity"

[linkwarden]
name = "Linkwarden"
description = "Bookmark and link manager"
category = "productivity"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/linkwarden.png"

[paperless]
name = "Paperless"
description = "Document management system"
category = "productivity"

# Development & Code
[forgejo]
name = "Forgejo"
description = "Git hosting and collaboration"
category = "development"

[opengist-http]
name = "OpenGist"
description = "Code snippet sharing"
category = "development"

# media & Media
[jellyfin]
name = "Jellyfin"
description = "Movies, TV shows, and music streaming"
category = "media"

[sonarr]
name = "Sonarr"
description = "TV show collection manager"
category = "media"

[radarr]
name = "Radarr"
description = "Movie collection manager"
category = "media"

[prowlarr]
name = "Prowlarr"
description = "Indexer manager for *arr apps"
category = "media"

[deluge]
name = "Deluge"
description = "BitTorrent client"
category = "media"

[snapcast]
name = "Snapcast"
description = "Multiroom audio streaming"
category = "media"

# Personal Cloud
[immich]
name = "Immich"
description = "Photo and video backup"
category = "personal cloud"

[open-webui]
name = "Open WebUI"
description = "LLM chat interface"
category = "personal cloud"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/open-webui.svg"
icon_dark = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/open-webui-light.svg"

[stalwart-http]
name = "Stalwart Mail"
description = "Email server"
category = "personal cloud"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/stalwart.svg"

# Smart Home
[home-assistant]
name = "Home Assistant"
description = "Smart home automation"
category = "smart home"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg"

[zigbee2mqtt]
name = "Zigbee2MQTT"
description = "Zigbee device bridge"
category = "smart home"

# Infrastructure & Monitoring
[authelia]
name = "Authelia"
description = "Single sign-on authentication"
category = "infrastructure"

[consul]
name = "Consul"
description = "Service discovery and configuration"
category = "infrastructure"

[grafana]
name = "Grafana"
description = "Metrics visualization and dashboards"
category = "infrastructure"

[victoriametrics]
name = "VictoriaMetrics"
description = "Long-term metrics storage"
category = "infrastructure"
path = "/vmui"
icon_dark = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/victoriametrics-light.svg"

[prometheus]
name = "Prometheus"
description = "Time-series metrics collector"
category = "infrastructure"

[alertmanager]
name = "Alertmanager"
description = "Alert routing and management"
category = "infrastructure"

[vmalert]
name = "VMAlert"
description = "Alerting rules engine"
category = "infrastructure"
path = "/vmalert"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/victoriametrics.svg"
icon_dark = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/victoriametrics-light.svg"

[nomad-ui]
name = "Nomad"
description = "Container orchestration"
category = "infrastructure"

[lldap]
name = "LLDAP"
description = "Lightweight LDAP server"
category = "infrastructure"
icon_dark = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/lldap-dark.svg"

# Network & Admin
[unifi]
name = "UniFi"
description = "Network management console"
category = "network"

[traefik-olympus]
name = "Traefik Olympus"
description = "Reverse proxy at Olympus"
category = "network"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/traefik.svg"

[traefik-erebus]
name = "Traefik Erebus"
description = "Reverse proxy at Erebus"
category = "network"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/traefik.svg"

[traefik-delphi]
name = "Traefik Delphi"
description = "Reverse proxy at Delphi"
category = "network"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/traefik.svg"

[traefik-ithaca]
name = "Traefik Ithaca"
description = "Reverse proxy at Ithaca"
category = "network"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/traefik.svg"

[traefik-external]
name = "Traefik External"
description = "External reverse proxy dashboard"
category = "network"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/traefik.svg"

# Tools
[it-tools]
name = "IT Tools"
description = "Collection of handy IT utilities"
category = "tools"
icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/it-tools.svg"

EOH
        destination   = "/app/services.toml"
      }

      # Discovered services (dynamic from Consul)
      template {
        data = <<EOH
{{ $domain := key "config/domains/main" }}
{
  "services": [
    {
      "id": "consul",
      "url": "https://consul.local.{{ $domain }}"
    }{{- range sprig_list "erebus" "olympus" "delphi" "ithaca" -}},
    {
      "id": "traefik-{{ . }}",
      "url": "https://traefik-{{ . }}.local.{{ $domain }}"
    }
    {{- end -}}
    {{- range services -}}
      {{- if .Tags | contains "traefik.enable=true" -}}
      {{- $host := "" -}}
        {{- range .Tags -}}
          {{- if . | regexMatch "rule=Host\\(" -}}
          {{- $host = . | regexReplaceAll ".*Host\\(`([^`]+)`\\).*" "$1" -}}
        {{- end -}}
      {{- end -}}
      {{- if $host -}},
    {
      "id": "{{ .Name }}",
      "url": "https://{{ $host }}"
    }
      {{- end -}}
  {{- end -}}
{{- end }}
  ]
}
EOH
        destination   = "/app/config.json"
        change_mode   = "signal"
        change_signal = "SIGHUP" # reload on change
      }

      service {
        name    = "homepage"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.homepage.rule=Host(`home.${PUBLIC_DOMAIN}`) || Host(`home.local.${PUBLIC_DOMAIN}`)",
          "traefik.http.routers.homepage.middlewares=authelia"
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
