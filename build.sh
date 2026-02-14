#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="/Users/pauli/Dev/CIF/circleci-aem"

# Load variables from .env
set -a
source "${SCRIPT_DIR}/.env"
set +a

QP_IMAGE_TAG="${QP_VERSION}-arm64"

# --- QP Image ---

echo "Downloading quick-provider ${QP_VERSION}..."
curl -# -u "${ARTIFACT_CRED}" \
  "${ARTIFACT_REPO}/com/adobe/qe/quick-provider/${QP_VERSION}/quick-provider-${QP_VERSION}-jar-with-dependencies.jar" \
  --output "${SCRIPT_DIR}/quick-provider-${QP_VERSION}-jar-with-dependencies.jar"

echo "Downloading qp.sh..."
curl -# -u "${ARTIFACT_CRED}" \
  "${ARTIFACT_REPO}/com/adobe/qe/quick-provider/${QP_VERSION}/quick-provider-${QP_VERSION}-script.sh" \
  --output "${SCRIPT_DIR}/qp.sh"
chmod +x "${SCRIPT_DIR}/qp.sh"

echo "Building QP image..."
docker build \
  --platform "${DOCKER_PLATFORM}" \
  --build-arg QP_VERSION="${QP_VERSION}" \
  --build-arg JACOCO_VERSION="${JACOCO_VERSION}" \
  -f "${SCRIPT_DIR}/Dockerfile.qp" \
  -t "aem-qp:${QP_IMAGE_TAG}" \
  "${SCRIPT_DIR}"

# --- AEM Image ---

echo "Copying cq-quickstart jar..."
cp "${SCRIPT_DIR}/cq-quickstart-${CQ_VERSION}-SNAPSHOT.jar" "${SCRIPT_DIR}/cq-quickstart.jar"

echo "Copying proxy and start.sh from source repo..."
cp -r "${SOURCE_DIR}/proxy" "${SCRIPT_DIR}/proxy"
sed -i '' 's|/home/circleci/cq|/home/aemuser/cq|g' "${SCRIPT_DIR}/proxy/index.js"
cp "${SOURCE_DIR}/start.sh" "${SCRIPT_DIR}/start.sh"

echo "Building AEM image..."
docker build \
  --platform "${DOCKER_PLATFORM}" \
  --build-arg QP_IMAGE_TAG="${QP_IMAGE_TAG}" \
  --build-arg CQ_VERSION="${CQ_VERSION}" \
  -f "${SCRIPT_DIR}/Dockerfile.aem" \
  -t "aem:${CQ_VERSION}-arm64" \
  "${SCRIPT_DIR}"
