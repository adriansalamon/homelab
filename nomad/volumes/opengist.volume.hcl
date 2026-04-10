name      = "opengist-data"
type      = "host"
plugin_id = "mkdir"
node_id   = "8b13b588-fae4-1d27-d2cf-9277212ccfa5"

capability {
  access_mode     = "single-node-single-writer"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "single-node-reader-only"
  attachment_mode = "file-system"
}
