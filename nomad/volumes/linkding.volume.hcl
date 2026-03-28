id        = "linkding-data"
name      = "linkding-data"
type      = "csi"
plugin_id = "seaweedfs"

capability {
  access_mode     = "multi-node-single-writer"
  attachment_mode = "file-system"
}
