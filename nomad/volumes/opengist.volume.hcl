name      = "opengist-data"
type      = "host"
plugin_id = "mkdir"
node_id   = "49512e1e-d203-0efe-41e2-165f03cc3af4"

capability {
  access_mode     = "single-node-single-writer"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "single-node-reader-only"
  attachment_mode = "file-system"
}
