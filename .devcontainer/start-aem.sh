#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONTAINER_NAME="aem-author"
AEM_IMAGE="aem:latest"
AEM_PORT=4502
CRX_VOLUME="aem-crx-quickstart"

# Wait for Docker daemon to be ready (DinD may still be starting)
echo "Waiting for Docker daemon..."
while ! docker info &>/dev/null; do sleep 1; done

# Build the AEM image if it doesn't exist
if ! docker image inspect "${AEM_IMAGE}" &>/dev/null; then
  echo "AEM image not found, building..."
  "${PROJECT_DIR}/build.sh"
fi

# Stop and remove existing container if running
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Ensure volume has correct ownership (named volumes default to root)
docker run --rm --user root \
  -v "${CRX_VOLUME}:/mnt/crx" \
  alpine chown -R 1000:1000 /mnt/crx

echo "Starting AEM container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p ${AEM_PORT}:${AEM_PORT} \
  -v "${CRX_VOLUME}:/home/aemuser/cq/author/crx-quickstart" \
  "${AEM_IMAGE}"

# Make volume data accessible and symlink into workspace for easy access
CRX_LINK="${SCRIPT_DIR}/crx-quickstart"
CRX_DATA="/var/lib/docker/volumes/${CRX_VOLUME}/_data"
sudo chmod o+rx /var/lib/docker /var/lib/docker/volumes "/var/lib/docker/volumes/${CRX_VOLUME}"
ln -sfn "${CRX_DATA}" "${CRX_LINK}"

echo "AEM author is starting on http://localhost:${AEM_PORT}"
