#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_NAME="aem-author"
AEM_IMAGE="aem:latest"
AEM_PORT=4502
CRX_MOUNT="${SCRIPT_DIR:-.}/crx-quickstart"

# Stop and remove existing container if running
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

mkdir -p "${CRX_MOUNT}"

echo "Starting AEM container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p ${AEM_PORT}:${AEM_PORT} \
  -v "${CRX_MOUNT}:/home/aemuser/cq/author/crx-quickstart" \
  "${AEM_IMAGE}"

echo "AEM author is starting on http://localhost:${AEM_PORT}"
