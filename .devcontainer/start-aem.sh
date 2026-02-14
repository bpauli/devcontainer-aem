#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_NAME="aem-author"
AEM_IMAGE="aem:6.6.0-arm64"
QP_PORT=55555
AEM_PORT=4502
PROXY_PORT=3000
CRX_MOUNT="${SCRIPT_DIR:-.}/crx-quickstart"

# Stop and remove existing container if running
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

mkdir -p "${CRX_MOUNT}"

echo "Starting AEM container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p ${AEM_PORT}:${AEM_PORT} \
  -p ${PROXY_PORT}:${PROXY_PORT} \
  -v "${CRX_MOUNT}:/home/aemuser/cq/author/crx-quickstart" \
  "${AEM_IMAGE}" \
  /bin/sh ./start.sh

echo "Waiting for QP server on port ${QP_PORT}..."
until docker exec "${CONTAINER_NAME}" sh -c "echo > /dev/tcp/localhost/${QP_PORT}" 2>/dev/null; do
  sleep 2
done
echo "QP server is ready."

echo "Binding to QP and starting AEM author..."
docker exec "${CONTAINER_NAME}" ./qp.sh -v bind --server-hostname localhost --server-port ${QP_PORT}
docker exec -w /home/aemuser/cq "${CONTAINER_NAME}" \
  bash -c './qp.sh -v start --id author --runmode author --port 4502 --qs-jar /home/aemuser/cq/author/cq-quickstart.jar --vm-options \"-Xmx1536m -Djava.awt.headless=true\"'

echo "AEM author is starting on http://localhost:${AEM_PORT}"
