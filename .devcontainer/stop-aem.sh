#!/bin/bash
set -euo pipefail

CONTAINER_NAME="aem-author"
CRX_VOLUME="aem-crx-quickstart"

echo "Stopping AEM container..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
echo "AEM container stopped."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--clear" ]]; then
  echo "Clearing crx-quickstart volume..."
  docker volume rm "${CRX_VOLUME}" 2>/dev/null || true
  rm -f "${SCRIPT_DIR}/crx-quickstart"
  echo "Volume cleared."
fi
