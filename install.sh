#!/bin/bash
set -euo pipefail

REPO="bpauli/devcontainer-aem"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

# Files to download (relative paths)
FILES=(
  "Dockerfile"
  "build.sh"
  "start.sh"
  ".env.example"
  ".devcontainer/devcontainer.json"
  ".devcontainer/start-aem.sh"
  ".devcontainer/stop-aem.sh"
)

echo "Installing AEM devcontainer into $(pwd)..."

# Create directories
mkdir -p .devcontainer

# Download files
for file in "${FILES[@]}"; do
  echo "  Downloading ${file}..."
  curl -fsSL "${BASE_URL}/${file}" -o "${file}"
done

# Make scripts executable
chmod +x build.sh start.sh .devcontainer/start-aem.sh .devcontainer/stop-aem.sh

# Create .env from .env.example if it doesn't exist
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "  Created .env from .env.example"
fi

# Append gitignore entries if not already present
GITIGNORE_ENTRIES=(
  "aem-sdk-quickstart.jar"
  "aem-sdk-*.zip"
  "aem-sdk-*.jar"
  "cq-quickstart*.jar"
  ".env"
)

if [[ -f .gitignore ]]; then
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "${entry}" .gitignore; then
      echo "${entry}" >> .gitignore
      echo "  Added '${entry}' to .gitignore"
    fi
  done
else
  printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > .gitignore
  echo "  Created .gitignore"
fi

echo ""
echo "AEM devcontainer installed."
echo ""
echo "Next steps:"
echo "  1. Download the AEM SDK from https://experience.adobe.com/#/downloads"
echo "  2. Unzip and rename the quickstart JAR to aem-sdk-quickstart.jar in this directory"
echo "  3. Open this folder in VS Code and reopen in container"
