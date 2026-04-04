job "alertmanager" {
  group "alertmanager" {
    count = 1

    network {
      port "http" {
        static = 24837
      }

      mode = "cni/nebula"
    }

    ephemeral_disk {
      size    = 300
      sticky  = true
      migrate = true
    }

    task "alertmanager" {
      driver = "docker"

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
                port  = "24837"
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = "24837"
                proto = "tcp"
                group = "reverse-proxy"
              },
              {
                port  = "24837"
                proto = "tcp"
                group = "metrics-ruler"
              }
            ]
          }
        })
      }

      config {
        image = "prom/alertmanager:v0.31.1"
        ports = ["http"]
        args = [
          "--config.file=${NOMAD_SECRETS_DIR}/alertmanager.yaml",
          "--web.listen-address=${NOMAD_ALLOC_IP_http}:${NOMAD_PORT_http}",
          "--web.external-url=https://alertmanager.local.${DOMAIN}",
          "--storage.path=${NOMAD_ALLOC_DIR}/alertmanager",
        ]
      }

      template {
        left_delimiter  = "[["
        right_delimiter = "]]"

        data        = <<EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['job', 'host']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: pushover

receivers:
  - name: pushover
    pushover_configs:[[ with nomadVar "nomad/jobs/alertmanager" ]]
      - user_key: [[ .pushover_user_key ]]
        token: [[ .pushover_app_key ]][[ end ]]
        send_resolved: true
        title: '{{ if eq .Status "resolved" }}✅ RESOLVED: {{ or .GroupLabels.alertname .CommonLabels.alertname "Alert" }}{{ else }}🚨 {{ or .GroupLabels.alertname .CommonLabels.alertname "Alert" }} ({{ .Alerts.Firing | len }}){{ end }}'
        message: |
          {{ if eq .Status "resolved" -}}
          {{ range $i, $alert := .Alerts.Resolved -}}
          {{ if lt $i 5 }}
          ✅ {{ or $alert.Annotations.summary $alert.Annotations.description "Alert resolved" }}
          {{ end -}}
          {{ end -}}
          {{ if gt (len .Alerts.Resolved) 5 }}
          ... and {{ len .Alerts.Resolved }} more resolved.
          {{ end -}}
          Duration: {{ with (index .Alerts.Resolved 0) }}{{ .StartsAt.Format "15:04" }} → {{ .EndsAt.Format "15:04 MST" }}{{ end }}
          {{- else -}}
          {{ range $i, $alert := .Alerts.Firing -}}
          {{ if lt $i 10 }}
          🔥 {{ or $alert.Annotations.summary "No summary" }}
          {{ if $alert.Annotations.description }}   {{ $alert.Annotations.description }}{{ end }}
          {{ end -}}
          {{ end -}}
          {{ if gt (len .Alerts.Firing) 10 }}
          ... and {{ len .Alerts.Firing }} more firing.
          {{ end -}}
          {{ with .CommonLabels -}}
          {{ if .host }}Host: {{ .host }}{{ end }}
          {{ if .instance }}Instance: {{ .instance }}{{ end }}
          {{- end }}
          {{- end }}
        html: true
        priority: '{{ if eq .Status "resolved" }}-1{{ else if eq .GroupLabels.severity "critical" }}1{{ else }}0{{ end }}'
        sound: '{{ if eq .Status "resolved" }}magic{{ else }}default{{ end }}'
        url: '{{ if gt (len .Alerts) 0 }}{{ (index .Alerts 0).GeneratorURL }}{{ else }}{{ .ExternalURL }}{{ end }}'
        url_title: '{{ if eq .Status "resolved" }}View history{{ else }}View alert{{ end }}'


inhibit_rules:
  - source_matchers:
      - severity="critical"
    target_matchers:
      - severity="warning"
    equal: ['host']
EOF
        destination = "${NOMAD_SECRETS_DIR}/alertmanager.yaml"
      }

      resources {
        cpu    = 100
        memory = 64
      }


      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }

      service {
        name    = "alertmanager"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.alertmanager.rule=Host(`alertmanager.local.${DOMAIN}`)"
        ]

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
