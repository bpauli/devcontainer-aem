#!/usr/bin/env node
import { createInterface } from 'node:readline';
import { mkdir, writeFile, readFile, chmod, access, constants } from 'node:fs/promises';
import { join } from 'node:path';
import https from 'node:https';
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
function download(url) {
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
            const chunks = [];
            res.on('data', (chunk) => chunks.push(chunk));
            res.on('end', () => resolve(Buffer.concat(chunks).toString()));
            res.on('error', reject);
        }).on('error', reject);
    });
}
async function fileExists(filePath) {
    try {
        await access(filePath, constants.F_OK);
        return true;
    }
    catch {
        return false;
    }
}
function question(rl, text) {
    return new Promise((resolve) => rl.question(text, resolve));
}
async function select(rl, prompt, options) {
    console.log(`\n${prompt}`);
    options.forEach((opt, i) => {
        const desc = opt.description ? ` — ${opt.description}` : '';
        console.log(`  ${i + 1}) ${opt.label}${desc}`);
    });
    while (true) {
        const answer = await question(rl, '\nSelect an option: ');
        const num = parseInt(answer.trim(), 10);
        if (num >= 1 && num <= options.length) {
            return options[num - 1].value;
        }
        console.log(`Please enter a number between 1 and ${options.length}.`);
    }
}
function applyClaudeCode(devcontainerContent) {
    const json = JSON.parse(devcontainerContent);
    json.features = json.features ?? {};
    json.features['ghcr.io/devcontainers/features/node:1'] = {};
    json.postCreateCommand = 'npm install -g @anthropic-ai/claude-code';
    return JSON.stringify(json, null, 2) + '\n';
}
async function main() {
    const cwd = process.cwd();
    const rl = createInterface({ input: process.stdin, output: process.stdout });
    try {
        console.log('AEM Devcontainer Setup');
        // --- Wizard ---
        const codingAgent = await select(rl, 'Select a coding agent:', [
            {
                label: 'Claude Code',
                description: 'installs @anthropic-ai/claude-code in the devcontainer',
                value: 'claude-code',
            },
            {
                label: 'Skip',
                description: 'no coding agent',
                value: 'skip',
            },
        ]);
        rl.close();
        console.log(`\nInstalling AEM devcontainer into ${cwd}...`);
        // --- Create directories ---
        await mkdir(join(cwd, '.devcontainer'), { recursive: true });
        // --- Download files ---
        for (const file of FILES) {
            process.stdout.write(`  Downloading ${file}...`);
            let content = await download(`${BASE_URL}/${file}`);
            if (file === '.devcontainer/devcontainer.json' && codingAgent === 'claude-code') {
                content = applyClaudeCode(content);
            }
            await writeFile(join(cwd, file), content);
            console.log(' done');
        }
        // --- Make scripts executable ---
        for (const script of EXECUTABLE_SCRIPTS) {
            await chmod(join(cwd, script), 0o755);
        }
        // --- Create .env from .env.example ---
        const envPath = join(cwd, '.env');
        if (!(await fileExists(envPath))) {
            const example = await readFile(join(cwd, '.env.example'), 'utf8');
            await writeFile(envPath, example);
            console.log('  Created .env from .env.example');
        }
        // --- Update .gitignore ---
        const gitignorePath = join(cwd, '.gitignore');
        if (await fileExists(gitignorePath)) {
            let content = await readFile(gitignorePath, 'utf8');
            const lines = content.split('\n');
            for (const entry of GITIGNORE_ENTRIES) {
                if (!lines.includes(entry)) {
                    content += `${entry}\n`;
                    console.log(`  Added '${entry}' to .gitignore`);
                }
            }
            await writeFile(gitignorePath, content);
        }
        else {
            await writeFile(gitignorePath, GITIGNORE_ENTRIES.join('\n') + '\n');
            console.log('  Created .gitignore');
        }
        // --- Done ---
        console.log('\nAEM devcontainer installed.');
        if (codingAgent === 'claude-code') {
            console.log('Claude Code will be installed automatically when the devcontainer starts.');
        }
        console.log('\nNext steps:');
        console.log('  1. Download the AEM SDK from https://experience.adobe.com/#/downloads');
        console.log('  2. Unzip and rename the quickstart JAR to aem-sdk-quickstart.jar in this directory');
        console.log('  3. Open this folder in VS Code and reopen in container');
    }
    catch (err) {
        rl.close();
        console.error(`\nError: ${err.message}`);
        process.exit(1);
    }
}
main();
