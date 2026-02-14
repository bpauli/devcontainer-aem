#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_NAME="aem-author"
CRX_MOUNT="${SCRIPT_DIR}/crx-quickstart"

echo "Stopping AEM container..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
echo "AEM container stopped."

if [[ "${1:-}" == "--clear" ]]; then
  echo "Clearing crx-quickstart mount..."
  rm -rf "${CRX_MOUNT}"
  echo "Mount cleared."
fi
