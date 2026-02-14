#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load variables from .env
set -a
source "${SCRIPT_DIR}/.env"
set +a

QS_JAR="${SCRIPT_DIR}/aem-sdk-quickstart.jar"

if [[ ! -f "${QS_JAR}" ]]; then
  echo "Error: aem-sdk-quickstart.jar not found."
  echo "Download the AEM SDK from https://experience.adobe.com/#/downloads and"
  echo "unzip and rename the quickstart JAR to aem-sdk-quickstart.jar."
  exit 1
fi

echo "Building AEM image..."
docker build \
  --platform "${DOCKER_PLATFORM}" \
  --build-arg UBUNTU_VERSION="${UBUNTU_VERSION}" \
  --build-arg JACOCO_VERSION="${JACOCO_VERSION}" \
  -f "${SCRIPT_DIR}/Dockerfile" \
  -t "aem:latest" \
  "${SCRIPT_DIR}"
