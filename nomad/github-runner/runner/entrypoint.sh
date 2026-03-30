#!/bin/bash
set -e

RUNNER_NAME="$(hostname)-$NOMAD_ALLOC_ID"

echo "Configuring GitHub Actions runner: $RUNNER_NAME"
echo "GitHub URL: $GITHUB_URL"
echo "Labels: $RUNNER_LABELS"

if [ ! -f ".runner" ]; then
  ./config.sh \
    --url "${GITHUB_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --unattended \
    --replace \
    --ephemeral

  echo "Runner configured successfully"
else
  echo "Runner already configured"
fi

echo "Starting runner..."
exec ./run.sh
