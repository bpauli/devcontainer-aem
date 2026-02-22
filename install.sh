#!/bin/bash
set -euo pipefail

# --- Constants ---
REPO="bpauli/devcontainer-aem"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

DOWNLOAD_FILES=(
  "Dockerfile"
  "build.sh"
  "start.sh"
  ".env.example"
  ".devcontainer/start-aem.sh"
  ".devcontainer/stop-aem.sh"
)

EXECUTABLE_SCRIPTS=(
  "build.sh"
  "start.sh"
  ".devcontainer/start-aem.sh"
  ".devcontainer/stop-aem.sh"
)

GITIGNORE_ENTRIES=(
  "aem-sdk-quickstart.jar"
  "aem-sdk-*.zip"
  "aem-sdk-*.jar"
  "cq-quickstart*.jar"
  ".devcontainer/crx-quickstart"
  ".env"
)

# --- ANSI colors ---
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
RED='\033[31m'
DIM='\033[2m'
BLUE='\033[34m'
RESET='\033[0m'

# --- Cleanup trap ---
cleanup() {
  rm -f ./*.bak .devcontainer/*.bak 2>/dev/null || true
}
trap cleanup EXIT

# --- Utility functions ---
error() {
  printf "${RED}  Error: %s${RESET}\n" "$1" >&2
  exit 1
}

validate_port() {
  local val="$1"
  if ! [[ "$val" =~ ^[0-9]+$ ]] || [ "$val" -lt 1 ] || [ "$val" -gt 65535 ]; then
    return 1
  fi
  return 0
}

download_file() {
  local url="$1"
  local dest="$2"
  if ! curl -fsSL "$url" -o "$dest"; then
    error "Failed to download $url"
  fi
}

# --- TTY input functions (required for curl|bash piping) ---
read_input() {
  local prompt="$1"
  local default="$2"
  local result

  if [ -n "$default" ]; then
    printf "  %s (%s): " "$prompt" "$default" > /dev/tty
  else
    printf "  %s: " "$prompt" > /dev/tty
  fi

  read -r result < /dev/tty || true
  if [ -z "$result" ]; then
    result="$default"
  fi
  echo "$result"
}

select_option() {
  local prompt="$1"
  shift
  local options=("$@")
  local count=${#options[@]}

  printf "\n  %s\n\n" "$prompt" > /dev/tty
  for i in "${!options[@]}"; do
    printf "    %d) %s\n" "$((i + 1))" "${options[$i]}" > /dev/tty
  done
  printf "\n" > /dev/tty

  while true; do
    printf "  Choice (1-%d): " "$count" > /dev/tty
    local choice
    read -r choice < /dev/tty || true
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
      echo "$((choice - 1))"
      return
    fi
    printf "  Please enter a number between 1 and %d\n" "$count" > /dev/tty
  done
}

# --- devcontainer.json generation ---
generate_devcontainer_json() {
  local agent="$1"
  local aem_port="$2"
  local debug_port="$3"

  local node_feature=""
  local post_create=""
  local forward_ports="${aem_port}, ${debug_port}"

  if [ "$agent" = "claude-code" ]; then
    node_feature=',
    "ghcr.io/devcontainers/features/node:1": {}'
    post_create='
  "postCreateCommand": "npm install -g @anthropic-ai/claude-code",'
  elif [ "$agent" = "codex" ]; then
    node_feature=',
    "ghcr.io/devcontainers/features/node:1": {}'
    post_create='
  "postCreateCommand": "npm install -g @openai/codex",'
  fi

  cat << DEVCONTAINER
{
  "name": "AEM Dev Environment",
  "image": "mcr.microsoft.com/devcontainers/java:21",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "moby": false
    },
    "ghcr.io/devcontainers/features/java:1": {
      "version": "none",
      "installMaven": "true"
    }${node_feature}
  },
  "forwardPorts": [${forward_ports}],${post_create}
  "postStartCommand": ".devcontainer/start-aem.sh",
  "customizations": {
    "vscode": {
      "extensions": [
        "vscjava.vscode-java-pack"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh",
        "workbench.colorTheme": "Default Dark Modern"
      }
    }
  }
}
DEVCONTAINER
}

# --- Shell script transforms ---
transform_start_sh() {
  local file="$1"
  local aem_port="$2"
  local debug_port="$3"

  # Port (if non-default)
  if [ "$aem_port" != "4502" ]; then
    sed -i.bak "s/-p 4502/-p ${aem_port}/" "$file"
    rm -f "${file}.bak"
  fi

  # Debug (always)
  sed -i.bak "s|exec java |exec java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${debug_port} |" "$file"
  rm -f "${file}.bak"
}

transform_start_aem_sh() {
  local file="$1"
  local aem_port="$2"
  local debug_port="$3"

  # Port (if non-default)
  if [ "$aem_port" != "4502" ]; then
    sed -i.bak "s/AEM_PORT=4502/AEM_PORT=${aem_port}/" "$file"
    rm -f "${file}.bak"
  fi

  # Debug port mapping (always) — add after the AEM port mapping line
  sed -i.bak "s|-p \${AEM_PORT}:\${AEM_PORT}|-p \${AEM_PORT}:\${AEM_PORT} \\\\\n  -p ${debug_port}:${debug_port}|" "$file"
  rm -f "${file}.bak"
}

# --- .env creation ---
create_env() {
  if [ ! -f ".env" ]; then
    cp ".env.example" ".env"
    printf "${GREEN}  ✓${RESET} Created .env from .env.example\n"
  fi
}

# --- .gitignore update ---
update_gitignore() {
  local added=false

  if [ -f ".gitignore" ]; then
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
      if ! grep -qxF "$entry" ".gitignore"; then
        echo "$entry" >> ".gitignore"
        added=true
      fi
    done
    if [ "$added" = true ]; then
      printf "${GREEN}  ✓${RESET} Updated .gitignore\n"
    fi
  else
    printf "%s\n" "${GITIGNORE_ENTRIES[@]}" > ".gitignore"
    printf "${GREEN}  ✓${RESET} Created .gitignore\n"
  fi
}

# --- Main ---
main() {
  # Preflight checks
  if ! command -v curl &>/dev/null; then
    error "curl is required but not found"
  fi

  if [ ! -w "." ]; then
    error "Current directory is not writable"
  fi

  # Warn if .devcontainer already exists
  if [ -d ".devcontainer" ]; then
    printf "\n${DIM}  Note: .devcontainer/ already exists, files will be overwritten${RESET}\n" > /dev/tty
  fi

  # --- Header ---
  printf "\n${BOLD}${CYAN}  AEM Devcontainer Setup${RESET}\n"

  # --- Wizard ---

  # 1. Coding agent
  local agent_choices=("Claude Code — installs @anthropic-ai/claude-code" "Codex — installs @openai/codex" "Skip — no coding agent")
  local agent_idx
  agent_idx=$(select_option "Select a coding agent:" "${agent_choices[@]}")
  local agent_values=("claude-code" "codex" "skip")
  local agent="${agent_values[$agent_idx]}"

  # 2. Port configuration
  printf "\n  ${BOLD}Port Configuration${RESET}\n\n" > /dev/tty

  local aem_port
  while true; do
    aem_port=$(read_input "AEM author port" "4502")
    if validate_port "$aem_port"; then
      break
    fi
    printf "  Please enter a valid port number (1-65535)\n" > /dev/tty
  done

  local debug_port
  while true; do
    debug_port=$(read_input "JVM debug port" "5005")
    if ! validate_port "$debug_port"; then
      printf "  Please enter a valid port number (1-65535)\n" > /dev/tty
      continue
    fi
    if [ "$debug_port" = "$aem_port" ]; then
      printf "  Debug port must be different from AEM port\n" > /dev/tty
      continue
    fi
    break
  done

  # --- Create directories ---
  mkdir -p .devcontainer

  # --- Download files ---
  printf "\n  Downloading files...\n"

  for file in "${DOWNLOAD_FILES[@]}"; do
    printf "  ${DIM}Downloading ${BLUE}%s${RESET}${DIM}...${RESET}\n" "$file"
    download_file "${BASE_URL}/${file}" "$file"
  done

  printf "${GREEN}  ✓${RESET} Files downloaded\n"

  # --- Generate devcontainer.json ---
  generate_devcontainer_json "$agent" "$aem_port" "$debug_port" > .devcontainer/devcontainer.json
  printf "${GREEN}  ✓${RESET} Generated devcontainer.json\n"

  # --- Apply transforms ---
  transform_start_sh "start.sh" "$aem_port" "$debug_port"
  transform_start_aem_sh ".devcontainer/start-aem.sh" "$aem_port" "$debug_port"

  # --- Make scripts executable ---
  for script in "${EXECUTABLE_SCRIPTS[@]}"; do
    chmod 755 "$script"
  done

  # --- Create .env ---
  create_env

  # --- Update .gitignore ---
  update_gitignore

  # --- Done ---
  printf "${BOLD}${GREEN}\n  Installation complete!${RESET}\n\n"

  if [ "$agent" != "skip" ]; then
    local agent_name
    if [ "$agent" = "claude-code" ]; then
      agent_name="Claude Code"
    else
      agent_name="Codex"
    fi
    printf "${DIM}  %s will be installed when the devcontainer starts.${RESET}\n\n" "$agent_name"
  fi

  printf "${BOLD}  Next steps:${RESET}\n\n"
  printf "  1. Download the AEM SDK from ${CYAN}https://experience.adobe.com/#/downloads${RESET}\n"
  printf "  2. Rename the quickstart JAR to ${BLUE}aem-sdk-quickstart.jar${RESET}\n"
  printf "  3. Open this folder in VS Code and reopen in container\n\n"
}

main
