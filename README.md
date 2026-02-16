# AEM Devcontainer

Run AEM as a Cloud Service locally inside a VS Code devcontainer using Docker-in-Docker.

## Prerequisites

- [VS Code](https://code.visualstudio.com/) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## Quick Install

Add the AEM devcontainer to an existing project:

```bash
npx github:bpauli/devcontainer-aem
```

Then follow the steps below starting from [Download the AEM SDK](#1-download-the-aem-sdk).

## Setup

### 1. Download the AEM SDK

Download the latest AEM SDK from the [Software Distribution portal](https://experience.adobe.com/#/downloads/content/software-distribution/en/aemcloud.html) (requires Adobe ID with AEM as a Cloud Service access).

Navigate to **AEM as a Cloud Service** and download the latest **AEM SDK** zip file.

See [Set up Local AEM Runtime](https://experienceleague.adobe.com/en/docs/experience-manager-learn/cloud-service/local-development-environment-set-up/aem-runtime) for details.

### 2. Extract and rename the quickstart JAR

Unzip the downloaded SDK zip:

```bash
unzip aem-sdk-2026.2.24288.20260204T121510Z-260100.zip
```

This produces a quickstart JAR like `aem-sdk-quickstart-2026.2.24288.20260204T121510Z-260100.jar`. Rename it:

```bash
mv aem-sdk-quickstart-*.jar aem-sdk-quickstart.jar
```

The file `aem-sdk-quickstart.jar` must be in the project root before building.

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env` if needed (defaults work for most setups).

### 4. Build the Docker image

```bash
./build.sh
```

### 5. Open in VS Code

Open this folder in VS Code and reopen in the devcontainer when prompted. AEM will start automatically and be available at http://localhost:4502.

## Usage

### Start AEM

AEM starts automatically when the devcontainer opens. To restart manually:

```bash
.devcontainer/start-aem.sh
```

### Stop AEM

```bash
.devcontainer/stop-aem.sh
```

To stop and clear all AEM data:

```bash
.devcontainer/stop-aem.sh --clear
```

### Logs

AEM logs are available at `.devcontainer/crx-quickstart/logs/` via the volume mount.
