# Vector ships logs from all nodes to Loki
# Based on https://atodorov.me/2021/07/09/logging-on-nomad-and-log-aggregation-with-loki/
job "vector" {
  # system job, runs on all nodes
  type = "system"

  update {
    min_healthy_time  = "10s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  group "vector" {
    count = 1

    restart {
      attempts = 3
      interval = "10m"
      delay    = "30s"
      mode     = "fail"
    }

    network {
      port "api" {}
      mode = "cni/flannel"
    }

    # docker socket volume
    volume "docker-socket" {
      type      = "host"
      source    = "docker-socket"
      read_only = true
    }

    ephemeral_disk {
      size   = 300
      sticky = true
    }

    task "vector" {
      driver = "docker"
      config {
        image = "timberio/vector:0.52.0-alpine"
        ports = ["api"]
      }

      # docker socket volume mount
      volume_mount {
        volume      = "docker-socket"
        destination = "/var/run/docker.sock"
        read_only   = true
      }

      # Vector won't start unless the sinks(backends) configured are healthy
      env {
        VECTOR_CONFIG          = "local/vector.toml"
        VECTOR_REQUIRE_HEALTHY = "true"
      }

      resources {
        cpu    = 300
        memory = 128
      }

      template {
        destination   = "local/vector.toml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        # overriding the delimiters to [[ ]] to avoid conflicts with Vector's native templating, which also uses {{ }}
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<EOH
          data_dir = "alloc/data/vector/"
          [api]
            enabled = true
            address = "0.0.0.0:[[ env "NOMAD_PORT_api" ]]"
            playground = true
          [sources.logs]
            type = "docker_logs"
            exclude_containers = ["vector"]
          [sinks.loki]
            type = "loki"
            inputs = [ "logs" ]
            endpoint = "http://zeus-loki.node.consul"
            encoding.codec = "json"
            healthcheck.enabled = true
            batch.max_bytes = 262144
            # remove fields that have been converted to labels to avoid having the field twice
            remove_label_fields = true
          [sinks.loki.labels]
            job = "{{label.\"com.hashicorp.nomad.job_name\" }}"
            task = "{{label.\"com.hashicorp.nomad.task_name\" }}"
            group = "{{label.\"com.hashicorp.nomad.task_group_name\" }}"
            namespace = "{{label.\"com.hashicorp.nomad.namespace\" }}"
            node = "{{label.\"com.hashicorp.nomad.node_name\" }}"
          [[ with nomadVar "nomad/jobs/vector" ]]
          [sinks.loki.auth]
            strategy = "basic"
            user = "[[ .username ]]"
            password = "[[ .password ]]"
          [[ end ]]
        EOH
      }

      service {
        check {
          port     = "api"
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "5s"
        }
      }

      kill_timeout = "30s"
    }
  }
}
