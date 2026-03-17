job "seaweedfs-csi" {
  type     = "system"
  priority = 90


  update {
    max_parallel = 1
    stagger      = "60s"
  }

  constraint {
    operator = "distinct_hosts"
    value    = true
  }

  constraint {
    attribute = "${attr.driver.docker.privileged.enabled}"
    value     = true
  }

  group "nodes" {

    network {
      mode = "cni/nebula"
    }

    task "plugin" {
      driver = "docker"

      meta {
        nebula_roles = jsonencode(["weed-filer-client"])
      }

      config {
        image = "chrislusf/seaweedfs-csi-driver:v1.3.5" # TODO: figure out how to upgrade to more recent versions
        args = [
          "--endpoint=unix://csi/csi.sock",
          "--filer=seaweedfs-filer.service.consul:20090",
          "--nodeid=${node.unique.name}",
          "--cacheCapacityMB=256",
          "--cacheDir=${NOMAD_TASK_DIR}/cache_dir",
        ]
        privileged = true
      }


      csi_plugin {
        id        = "seaweedfs"
        type      = "monolith"
        mount_dir = "/csi"
      }


      resources {
        cpu        = 800
        memory     = 512
        memory_max = 1024
      }
    }
  }
}
