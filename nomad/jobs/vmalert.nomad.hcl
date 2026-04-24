job "vmalert" {
  group "vmalert" {
    count = 1

    network {
      port "http" {
        static = 13691
      }

      mode = "cni/nebula"
    }

    task "vmalert" {
      driver = "docker"

      consul {}

      meta {
        nebula_roles = jsonencode(["metrics-ruler"])
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
                port  = "13691"
                proto = "tcp"
                group = "reverse-proxy"
              },
              {
                port  = "13691"
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = "13691"
                proto = "tcp"
                group = "metrics-store"
              }
            ]
          }
        })
      }

      config {
        image = "victoriametrics/vmalert:v1.140.0"
        ports = ["http"]
        args = [
          "-datasource.url=http://srv+lb-metrics.service.consul",
          "-remoteWrite.url=http://srv+prometheus.service.consul",
          "-remoteRead.url=http://srv+lb-metrics.service.consul",
          "-notifier.config=${NOMAD_ALLOC_DIR}/notifier.yaml",
          "-rule=${NOMAD_ALLOC_DIR}/rules/*.yaml",
          "-httpListenAddr=${NOMAD_ALLOC_IP_http}:${NOMAD_PORT_http}",
          "-external.url=https://vmalert.local.${DOMAIN}"
        ]
      }

      template {
        data        = <<EOF
consul_sd_configs:
  - server: consul.local.{{ key "config/domains/main" }}
    scheme: "https"
    token: {{ env "CONSUL_TOKEN" }}
    services:
      - alertmanager
EOF
        destination = "${NOMAD_ALLOC_DIR}/notifier.yaml"
      }

      template {
        left_delimiter  = "[["
        right_delimiter = "]]"

        data        = <<EOF
groups:
  - name: metrics.Alerts
    interval: 5m
    rules:
      - alert: MemoryUsage
        expr: 100 * (mem_used - sum(zfs_arcstats_size) by (host, instance, job)) / mem_total > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: High memory usage on {{ $labels.host }}
          description: Host {{ $labels.host }} memory usage is {{ $value | humanize }}%.

      - alert: SystemdFailures
        expr: systemd_units_active_code == 3
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: Systemd unit {{ $labels.name }} failing
          description: Systemd unit {{ $labels.name }} failing on host {{ $labels.instance }}

  - name: metrics.Infrequent
    interval: 1h
    rules:
      - alert: StorageCheck
        expr: disk_used_percent{fstype!~"(.*tmp.*|efivarfs)"} > 90
        for: 2h
        labels:
          severity: warning
        annotations:
          summary: Storage device {{ $labels.device }} full
          description: Device {{ $labels.device }} on {{ $labels.host }} is {{ $value | humanize }}% full.

  - name: monitoring.Monitor
    interval: 5m
    rules:
      - alert: HTTPHealthCheckFailure
        expr: http_response_result_code > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.name }} is down from {{ $labels.host }}"
          description: HTTP health check for {{ $labels.name }} from {{ $labels.host }} is failing with result {{ $labels.result }}

      - alert: DNSQueryFailure
        expr: dns_query_result_code > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: DNS query failed from {{ $labels.host }} to {{ $labels.name }}
          description: DNS query for {{ $labels.domain }} ({{ $labels.record_type }}) from {{ $labels.host }} failed with rcode {{ $labels.rcode }}

      - alert: PingPacketLoss
        expr: ping_percent_packet_loss > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Packet loss to {{ $labels.name }} from {{ $labels.host }}
          description: "{{ $labels.host }} is experiencing {{ $value | humanize }}% packet loss to {{ $labels.name }} ({{ $labels.url }})"

  - name: backups.BackupCheck
    interval: 5m
    rules:
      - alert: ZreplErrors
        expr: zrepl_replication_filesystem_errors > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Zrepl replication errors on {{ $labels.instance }}
          description: Host {{ $labels.instance }} has {{ $value }} filesystem errors for job {{ $labels.zrepl_job }}

  - name: backups.Infrequent
    interval: 5h
    rules:
      - alert: StaleResticBackup
        expr: time() - topk(1, rustic_snapshot_timestamp) by (repo_id) > 1209600
        for: 5h
        labels:
          severity: warning
        annotations:
          summary: Restic backup stale for repo {{ $labels.repo_name }}
          description: "No backup taken for repo {{ $labels.repo_name }} in the last 14 days. Last backup was {{ $value | humanizeDuration }} ago."
EOF
        destination = "${NOMAD_ALLOC_DIR}/rules/rules.yaml"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }

      service {
        name    = "vmalert"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.vmalert.rule=Host(`vmalert.local.${DOMAIN}`) && PathPrefix(`/vmalert`)",
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
