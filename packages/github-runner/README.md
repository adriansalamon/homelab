## GitHub Actions Self-Hosted Runners on Nomad

Based on https://github.com/bfbarkhouse/nomad-gh-runner/tree/80d0b05

### Architecture

1. **Webhook Server**: Receives GitHub webhook events when workflows are queued
2. **Runner Jobs**: Ephemeral Nomad batch jobs that register as GitHub runners and execute workflows
