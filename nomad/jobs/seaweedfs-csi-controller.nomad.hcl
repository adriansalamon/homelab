job "seaweedfs-csi-controller" {

  update {
    max_parallel = 1
    stagger      = "45s"
  }

  group "controller" {

    network {
      mode = "cni/nebula"
    }

    task "controller" {
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

      config {
        image = "chrislusf/seaweedfs-csi-driver:v1.4.5"
        args = [
          "--endpoint=unix:///csi-sock/csi.sock",
          "--filer=seaweedfs-filer.service.consul:20090",
          "--components=controller"
        ]
      }

      csi_plugin {
        id        = "seaweedfs"
        type      = "controller"
        mount_dir = "/csi-sock"
      }

      resources {
        cpu    = 100
        memory = 100
      }
    }
  }
}
