job "seaweedfs-csi-node" {
  type = "system"

  update {
    max_parallel = 1
    stagger      = "45s"
  }

  group "nodes" {

    network {
      mode = "cni/nebula"
    }

    volume "seaweedfs_mount_socket" {
      type      = "host"
      source    = "seaweedfs-socket"
      read_only = false
    }

    # host directory where Nomad CSI stage/publish paths live
    volume "csi_staging" {
      type      = "host"
      source    = "csi-data"
      read_only = false
    }

    task "plugin" {
      driver = "docker"

      meta {
        nebula_roles = jsonencode(["weed-filer-client"])

        nebula_config = yamlencode({
          firewall = {
            outbound = [
              {
                port  = "any"
                proto = "any"
                host  = "any"
              }
            ]
          }
        })
      }

      volume_mount {
        volume      = "seaweedfs_mount_socket"
        destination = "/var/lib/seaweedfs-mount"
        read_only   = false
      }

      config {
        image      = "chrislusf/seaweedfs-csi-driver:v1.4.8"
        privileged = true
        args = [
          "--endpoint=unix:///csi-sock/csi.sock",
          "--filer=seaweedfs-filer.service.consul:20090",
          "--dataCenter=${node.datacenter}",
          "--nodeid=${node.unique.name}",
          "--cacheCapacityMB=1024",
          "--cacheDir=${NOMAD_ALLOC_DIR}/cache_dir",
          "--mountEndpoint=unix:///var/lib/seaweedfs-mount/seaweedfs-mount.sock",
          "--dataLocality=none",
          "--components=node",
        ]
      }

      csi_plugin {
        id                     = "seaweedfs"
        type                   = "node"
        mount_dir              = "/csi-sock"
        stage_publish_base_dir = "/csi-data/node/seaweedfs"
      }

      resources {
        cpu    = 100
        memory = 300
      }
    }


    task "mount-service" {
      driver = "docker"

      volume_mount {
        volume      = "seaweedfs_mount_socket"
        destination = "/var/lib/seaweedfs-mount"
        read_only   = false
      }

      # required for proper propagation of staged mounts into the host filesystem
      volume_mount {
        volume           = "csi_staging"
        destination      = "/csi-data"
        read_only        = false
        propagation_mode = "bidirectional"
      }

      config {
        image      = "chrislusf/seaweedfs-mount:v1.4.6"
        privileged = true
        args = [
          "--endpoint=unix:///var/lib/seaweedfs-mount/seaweedfs-mount.sock",
        ]
      }

      resources {
        cpu    = 200
        memory = 1024
      }
    }
  }
}
