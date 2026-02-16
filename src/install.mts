#!/usr/bin/env node

import { mkdir, writeFile, readFile, chmod, access, constants } from 'node:fs/promises';
import { join } from 'node:path';
import https from 'node:https';
import { select, input, confirm } from '@inquirer/prompts';
import pc from 'picocolors';
import ora, { type Ora } from 'ora';

const REPO = 'bpauli/devcontainer-aem';
const BRANCH = 'main';
const BASE_URL = `https://raw.githubusercontent.com/${REPO}/${BRANCH}`;

const FILES = [
  'Dockerfile',
  'build.sh',
  'start.sh',
  '.env.example',
  '.devcontainer/devcontainer.json',
  '.devcontainer/start-aem.sh',
  '.devcontainer/stop-aem.sh',
];

const EXECUTABLE_SCRIPTS = [
  'build.sh',
  'start.sh',
  '.devcontainer/start-aem.sh',
  '.devcontainer/stop-aem.sh',
];

const GITIGNORE_ENTRIES = [
  'aem-sdk-quickstart.jar',
  'aem-sdk-*.zip',
  'aem-sdk-*.jar',
  'cq-quickstart*.jar',
  '.devcontainer/crx-quickstart',
  '.env',
];

interface DevcontainerJson {
  features?: Record<string, Record<string, unknown>>;
  forwardPorts?: number[];
  postCreateCommand?: string;
  [key: string]: unknown;
}

function download(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        download(res.headers.location).then(resolve, reject);
        return;
      }
      if (res.statusCode !== 200) {
        reject(new Error(`Failed to download ${url} (HTTP ${res.statusCode})`));
        res.resume();
        return;
      }
      const chunks: Buffer[] = [];
      res.on('data', (chunk: Buffer) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks).toString()));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await access(filePath, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

function applyCodingAgent(devcontainerContent: string, agent: string): string {
  if (agent === 'skip') return devcontainerContent;

  const json: DevcontainerJson = JSON.parse(devcontainerContent);
  json.features = json.features ?? {};
  json.features['ghcr.io/devcontainers/features/node:1'] = {};

  const packages: Record<string, string> = {
    'claude-code': '@anthropic-ai/claude-code',
    'codex': '@openai/codex',
  };

  json.postCreateCommand = `npm install -g ${packages[agent]}`;
  return JSON.stringify(json, null, 2) + '\n';
}

function applyPorts(content: string, file: string, aemPort: number): string {
  if (file === 'start.sh') {
    return content.replace(/-p 4502\b/, `-p ${aemPort}`);
  }
  if (file === '.devcontainer/start-aem.sh') {
    return content.replace(/AEM_PORT=4502/, `AEM_PORT=${aemPort}`);
  }
  if (file === '.devcontainer/devcontainer.json') {
    const json: DevcontainerJson = JSON.parse(content);
    json.forwardPorts = [aemPort];
    return JSON.stringify(json, null, 2) + '\n';
  }
  return content;
}

function applyDebug(content: string, file: string, debugPort: number): string {
  if (file === 'start.sh') {
    return content.replace(
      /exec java /,
      `exec java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${debugPort} `,
    );
  }
  if (file === '.devcontainer/start-aem.sh') {
    // Add debug port mapping to docker run
    return content.replace(
      /-p \$\{AEM_PORT\}:\$\{AEM_PORT\}/,
      `-p \${AEM_PORT}:\${AEM_PORT} \\\n  -p ${debugPort}:${debugPort}`,
    );
  }
  if (file === '.devcontainer/devcontainer.json') {
    const json: DevcontainerJson = JSON.parse(content);
    json.forwardPorts = [...(json.forwardPorts ?? []), debugPort];
    return JSON.stringify(json, null, 2) + '\n';
  }
  return content;
}

function validatePort(val: string): string | true {
  const num = parseInt(val, 10);
  if (isNaN(num) || num < 1 || num > 65535) {
    return 'Please enter a valid port number (1-65535)';
  }
  return true;
}

async function main(): Promise<void> {
  const cwd = process.cwd();
  let spinner: Ora | undefined;

  try {
    console.log('\n' + pc.bold(pc.cyan('  AEM Devcontainer Setup')) + '\n');

    // --- Wizard ---
    const codingAgent = await select({
      message: 'Select a coding agent:',
      choices: [
        { name: 'Claude Code', value: 'claude-code', description: 'installs @anthropic-ai/claude-code' },
        { name: 'Codex', value: 'codex', description: 'installs @openai/codex' },
        { name: 'Skip', value: 'skip', description: 'no coding agent' },
      ],
    });

    const aemPortStr = await input({
      message: 'AEM author port:',
      default: '4502',
      validate: validatePort,
    });
    const aemPort = parseInt(aemPortStr, 10);

    const enableDebug = await confirm({
      message: 'Enable JVM remote debugging?',
      default: true,
    });

    let debugPort: number | undefined;
    if (enableDebug) {
      const debugPortStr = await input({
        message: 'JVM debug port:',
        default: '5005',
        validate: (val) => {
          const result = validatePort(val);
          if (result !== true) return result;
          if (parseInt(val, 10) === aemPort) {
            return 'Debug port must be different from AEM port';
          }
          return true;
        },
      });
      debugPort = parseInt(debugPortStr, 10);
    }

    // --- Create directories ---
    await mkdir(join(cwd, '.devcontainer'), { recursive: true });

    // --- Download files ---
    spinner = ora('Downloading files...').start();

    for (const file of FILES) {
      spinner.text = `Downloading ${pc.blue(file)}...`;
      let content = await download(`${BASE_URL}/${file}`);

      // Apply coding agent
      if (file === '.devcontainer/devcontainer.json') {
        content = applyCodingAgent(content, codingAgent);
      }

      // Apply port customization
      if (aemPort !== 4502) {
        content = applyPorts(content, file, aemPort);
      }

      // Apply debug configuration
      if (debugPort !== undefined) {
        content = applyDebug(content, file, debugPort);
      }

      await writeFile(join(cwd, file), content);
    }

    spinner.succeed('Files downloaded');

    // --- Make scripts executable ---
    for (const script of EXECUTABLE_SCRIPTS) {
      await chmod(join(cwd, script), 0o755);
    }

    // --- Create .env from .env.example ---
    const envPath = join(cwd, '.env');
    if (!(await fileExists(envPath))) {
      const example = await readFile(join(cwd, '.env.example'), 'utf8');
      await writeFile(envPath, example);
      console.log(pc.green('  \u2713') + ' Created .env from .env.example');
    }

    // --- Update .gitignore ---
    const gitignorePath = join(cwd, '.gitignore');
    if (await fileExists(gitignorePath)) {
      let content = await readFile(gitignorePath, 'utf8');
      const lines = content.split('\n');
      let added = false;
      for (const entry of GITIGNORE_ENTRIES) {
        if (!lines.includes(entry)) {
          content += `${entry}\n`;
          added = true;
        }
      }
      if (added) {
        await writeFile(gitignorePath, content);
        console.log(pc.green('  \u2713') + ' Updated .gitignore');
      }
    } else {
      await writeFile(gitignorePath, GITIGNORE_ENTRIES.join('\n') + '\n');
      console.log(pc.green('  \u2713') + ' Created .gitignore');
    }

    // --- Done ---
    console.log(pc.bold(pc.green('\n  Installation complete!\n')));

    if (codingAgent !== 'skip') {
      const agentName = codingAgent === 'claude-code' ? 'Claude Code' : 'Codex';
      console.log(pc.dim(`  ${agentName} will be installed when the devcontainer starts.\n`));
    }

    console.log(pc.bold('  Next steps:\n'));
    console.log(`  1. Download the AEM SDK from ${pc.cyan('https://experience.adobe.com/#/downloads')}`);
    console.log(`  2. Rename the quickstart JAR to ${pc.blue('aem-sdk-quickstart.jar')}`);
    console.log('  3. Open this folder in VS Code and reopen in container\n');
  } catch (err) {
    if ((err as Error).name === 'ExitPromptError') {
      console.log(pc.dim('\n  Setup cancelled.\n'));
      process.exit(0);
    }
    spinner?.fail('Download failed');
    console.error(pc.red(`\n  Error: ${(err as Error).message}\n`));
    process.exit(1);
  }
}

main();
