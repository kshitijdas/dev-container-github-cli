# Dev Container Setup Guide

A complete, step-by-step guide to setting up and using this repository's dev container on the Rio Tinto corporate network.

---

## Table of Contents

1. [What Is a Dev Container?](#1-what-is-a-dev-container)
2. [Prerequisites](#2-prerequisites)
3. [Repository Structure](#3-repository-structure)
4. [Files Inside `.devcontainer`](#4-files-inside-devcontainer)
5. [Certificate Files — What They Are and Why They Matter](#5-certificate-files--what-they-are-and-why-they-matter)
6. [Step-by-Step Setup](#6-step-by-step-setup)
7. [First-Time Container Build](#7-first-time-container-build)
8. [Verifying the Environment](#8-verifying-the-environment)
9. [Working with GitHub Copilot CLI](#9-working-with-github-copilot-cli)
10. [Switching Between Image and Dockerfile Build](#10-switching-between-image-and-dockerfile-build)
11. [Private Registries and Network Requirements](#11-private-registries-and-network-requirements)
12. [Troubleshooting](#12-troubleshooting)
13. [FAQ](#13-faq)

---

## 1. What Is a Dev Container?

A dev container is a full development environment defined as code. When you open this repository in VS Code, Docker builds a container with the correct Python version, fonts, CLI tools, certificates, and extensions — every developer on the team gets an identical setup regardless of their host machine.

Key benefits for this project:

- Corporate TLS certificates baked in so `git`, `pip`, and `curl` all work without manual cert trust workarounds
- GitHub CLI (`gh`) and GitHub Copilot CLI pre-installed
- Node.js (LTS) available for tooling
- A `post-create.sh` script that wires up private registry access and installs Copilot CLI automatically

---

## 2. Prerequisites

Before you start, confirm every item below.

### 2.1 Network

| Requirement | Detail |
|---|---|
| Rio Tinto network or VPN | Must be active — Artifactory and private registries are not reachable otherwise |
| Docker Hub proxy | `dockerhub.artifactory.riotinto.com` — used as the base image source |
| Artifactory PyPI | Configured via `etc/pip.conf` in this repo |
| Artifactory NPM | `https://artifactory.riotinto.com/artifactory/api/npm/riotinto-npm/` |

Refer to these links 
1. [Artifactory Token](https://riotinto.sharepoint.com/sites/5059953/SitePages/Artifactory---Setting-up-Credentials-(Identity-Token).aspx) 
2. [PIP conf](https://riotinto.sharepoint.com/sites/5059953/SitePages/Configuring-pip-to-use-Artifactory.aspx)
### 2.2 Local Tooling

| Tool | Minimum Version | Notes |
|---|---|---|
| Docker Desktop / Docker Engine | 24+ | Engine must be running before you open VS Code |
| VS Code | Latest stable | |
| VS Code Dev Containers extension | Latest | Extension ID: `ms-vscode-remote.remote-containers` |
| WSL 2 (Windows only) | Enabled | Clone the repo inside WSL, not on the Windows `C:\` drive |
| Git | Any recent version | |

### 2.3 Repository Access

You need read access to this GitHub repository. If you cloned via HTTPS, make sure your PAT is configured.

### 2.4 Certificate Files

Two `.crt` files must be present inside `.devcontainer/` before you build:

- `RTNetworkSecurityTrust.crt`
- `zia.corp.riotinto.org.crt`

---

## 3. Repository Structure

```
.
├── .devcontainer/
│   ├── devcontainer.json          # Container definition and VS Code config
│   ├── dockerfile                 # Dockerfile for cert-injected Artifactory build
│   ├── post-create.sh             # Runs once after container creation
│   ├── RTNetworkSecurityTrust.crt # — corporate root CA
│   └── zia.corp.riotinto.org.crt  #  — Zscaler intermediate CA
├── etc/
│   └── pip.conf                   # pip private registry configuration
└── SETUP.md                       # This guide
```

---

## 4. Files Inside `.devcontainer`

All configuration files live in [`.devcontainer/`](.devcontainer/). Below is a description of each file's role. You do not need to edit these files for a standard setup.

### [`devcontainer.json`](.devcontainer/devcontainer.json)

The primary configuration file that VS Code reads. It defines:

- **Base image** — pulls `riotinto-docker.artifactory.riotinto.com/ist/tech-platforms/.../python` from Artifactory instead of Docker Hub, ensuring the correct Rio Tinto approved image is used
- **Features** — installs GitHub Copilot CLI, GitHub CLI, and Node.js LTS directly from Rio Tinto's mirrored feature registry (`ghcr.artifactory.riotinto.com`)
- **`postCreateCommand`** — points to `post-create.sh` so it runs automatically after the container is first built
- **`containerEnv`** — sets `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` so Python's `requests` library and `pip` both trust the OS certificate bundle; also sets the NPM registry to Artifactory
- **Dockerfile fallback** — a commented-out `build` block is included if you need to switch from the pre-built image to a Dockerfile-based build (see [Section 10](#10-switching-between-image-and-dockerfile-build))

### [`dockerfile`](.devcontainer/dockerfile)

Used only when the `build` block in `devcontainer.json` is uncommented. It:

- Starts from `dockerhub.artifactory.riotinto.com/python:3.12` (the Artifactory-mirrored Python image)
- Copies both `.crt` files into `/usr/local/share/ca-certificates/`
- Runs `update-ca-certificates` to register them with the OS trust store
- Sets `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` environment variables
- Installs Node.js LTS via the NodeSource script mirrored through Artifactory
- Configures npm to use the Artifactory registry and globally installs `@github/copilot`
- Installs `git`, `curl`, and `openssl` as baseline tools

> Note: The Dockerfile patches a broken Yarn apt source that ships on some base images — this is expected and intentional.

### [`post-create.sh`](.devcontainer/post-create.sh)

A bash script that runs **once**, automatically, after the container is created. It:

1. Copies `etc/pip.conf` into `~/.config/pip/pip.conf` so that `pip install` routes through Artifactory's PyPI proxy
2. Installs GitHub CLI (`gh`) from a private APT repository if it is not already present — reads the repo URL from the `PRIVATE_APT_GITHUB_CLI_REPO` environment variable
3. Installs GitHub Copilot CLI (`github-copilot-cli`) from the Artifactory NPM registry if it is not already present — reads the registry URL from `NPM_CONFIG_REGISTRY` or `PRIVATE_NPM_REGISTRY`

The script uses `set -e` so it exits immediately if any step fails, making failures visible rather than silent.

---

## 5. Certificate Files — What They Are and Why They Matter

Rio Tinto's network uses TLS inspection (Zscaler). When any tool inside the container makes an HTTPS request — `pip install`, `git clone`, `curl`, `npm install` — the response is signed by Rio Tinto's internal CA chain rather than a public root CA. Without these certificates in the OS trust store, every HTTPS call fails with a certificate verification error.

The two files required:

| File | Purpose |
|---|---|
| `RTNetworkSecurityTrust.crt` | Rio Tinto's root CA certificate |
| `zia.corp.riotinto.org.crt` | Zscaler intermediate CA certificate |



---

## 6. Step-by-Step Setup

### Step 1 — Clone the repository (inside WSL on Windows)

```bash
# Windows: open your WSL terminal, not PowerShell or CMD
cd ~
git clone https://github.com/kshitijdas/dev-container-github-cli.git
cd dev-container-github-cli
```

On macOS or Linux, clone wherever you prefer.

> **Windows note:** Always clone inside the WSL filesystem (e.g. `~/projects/`), never under `/mnt/c/`. Docker bind-mounts from the Windows filesystem are significantly slower and can cause file permission issues.


### Step 2 — Open in VS Code

```bash
code .
```

VS Code will detect the `.devcontainer/` folder and show a notification in the bottom-right corner:

> **"Folder contains a Dev Container configuration file. Reopen in Container?"**

Click **Reopen in Container**.

Alternatively, press `F1` → type `Dev Containers: Reopen in Container` → Enter.

### Step 3 — Wait for the build

The first build pulls the base image from Artifactory and runs `post-create.sh`. This typically takes **3–8 minutes** depending on your connection to the internal registry.

Progress is shown in the VS Code terminal. You can click **"show log"** in the notification to follow along in detail.

---

## 7. First-Time Container Build

What happens during the build, in order:

1. VS Code reads `.devcontainer/devcontainer.json`
2. Docker pulls the base image from `riotinto-docker.artifactory.riotinto.com`
3. Dev Container features (GitHub CLI, Copilot CLI, Node.js) are injected
4. Container environment variables are applied
5. `post-create.sh` runs:
   - `pip.conf` is copied to configure pip with the Artifactory PyPI index
   - GitHub CLI is verified / installed
   - GitHub Copilot CLI is verified / installed via npm

On **subsequent reopens**, the image is already cached by Docker — startup takes only a few seconds.

To force a full rebuild (e.g. after changing `devcontainer.json`):

```
F1 → Dev Containers: Rebuild Container
```

---

## 8. Verifying the Environment

Once the container is running, open a new terminal (`Ctrl + \``) and run the checks below.

### 8.1 Certificates

```bash
ls /etc/ssl/certs | grep -i riotinto
ls /etc/ssl/certs | grep -i zia
```

You should see both certificate names. If neither appears, the certs were not installed correctly — see [Troubleshooting](#12-troubleshooting).

For a full handshake test:

```bash
openssl s_client -connect artifactory.riotinto.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt
```

Look for `Verify return code: 0 (ok)` near the end of the output.

### 8.2 Python and pip

```bash
python --version          # Should print Python 3.12.x
which python              # Should be inside /usr/local/bin or similar
pip config list           # Should show the Artifactory index-url
pip install requests      # Quick install test — should succeed without SSL errors
```

### 8.3 GitHub CLI

```bash
gh --version
gh auth status            # Should show your logged-in GitHub account
```

If not authenticated:

```bash
gh auth login
```

Follow the prompts. Use HTTPS and authenticate via browser or PAT.

### 8.4 GitHub Copilot CLI

```bash
copilot --version
```
If this works login to Copilot CLI
```bash
copilot
```

### 8.5 Node.js

```bash
node --version            # Should print v20.x.x or similar LTS version
npm --version
npm config get registry   # Should point to Artifactory NPM
```


---

## 10. Switching Between Image and Dockerfile Build

By default, `devcontainer.json` uses a **pre-built image** from Artifactory. This is the fastest option.

If you need to inject custom OS-level dependencies (e.g. a new system package), you can switch to the **Dockerfile build**:

1. Open [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json)
2. Comment out the `"image"` line
3. Uncomment the `"build"` block that references `dockerfile`
4. Edit [`.devcontainer/dockerfile`](.devcontainer/dockerfile) with your changes
5. Rebuild the container: `F1 → Dev Containers: Rebuild Container`

The Dockerfile approach also handles certificate injection explicitly (via `COPY` + `update-ca-certificates`), which is useful when the pre-built image does not include them.

---

## 11. Private Registries and Network Requirements

| Registry | URL | Used For |
|---|---|---|
| Artifactory Docker | `riotinto-docker.artifactory.riotinto.com` | Container base image |
| Artifactory Docker Hub mirror | `dockerhub.artifactory.riotinto.com` | Dockerfile base image |
| Artifactory PyPI | Configured in `etc/pip.conf` | `pip install` |
| Artifactory NPM | `https://artifactory.riotinto.com/artifactory/api/npm/riotinto-npm/` | `npm install` |
| Artifactory ghcr mirror | `ghcr.artifactory.riotinto.com` | Dev Container features |

All of these are only reachable when Artifactory is setup. For docker artifactory urls run `docker login <URL> ` commands with artifcatory token registered.

### `pip.conf`

The file at [`etc/pip.conf`](etc/pip.conf) configures pip to use Artifactory as both the primary index and the extra index. This is copied into the container home directory by `post-create.sh` at container creation time.

---

## 12. Troubleshooting

### Certificate verification errors during `pip install` or `git clone`

**Symptom:** `SSL: CERTIFICATE_VERIFY_FAILED` or `unable to get local issuer certificate`

**Cause:** The certificate files were missing or malformed, or the environment variables are not set.

**Fix:**
1. Confirm both `.crt` files are in `.devcontainer/`
2. Rebuild the container: `F1 → Dev Containers: Rebuild Container`
3. After rebuild, verify: `ls /etc/ssl/certs | grep riotinto`
4. Confirm env vars: `echo $REQUESTS_CA_BUNDLE` should print `/etc/ssl/certs/ca-certificates.crt`

---

### Cannot pull base image from Artifactory

**Symptom:** `Error response from daemon: pull access denied` or `no such host`

**Cause:** Docker is not logged in to the Artifactory registry, or you are off-network.

**Fix:**
```bash
docker login riotinto-docker.artifactory.riotinto.com
```

Enter your Rio Tinto Artifactory credentials (same as your internal SSO in most setups). Then retry the container build.

---

### `post-create.sh` fails at GitHub CLI step

**Symptom:** `PRIVATE_APT_GITHUB_CLI_REPO is not set (private-only mode)`

**Cause:** The environment variable pointing to the private apt repository is not defined.

**Fix:** Ask your team lead for the correct value for `PRIVATE_APT_GITHUB_CLI_REPO` and add it to your environment or to a `.env` file referenced in `devcontainer.json`.

---

### `post-create.sh` fails at Copilot CLI step

**Symptom:** `PRIVATE_NPM_REGISTRY or NPM_CONFIG_REGISTRY is not set`

**Cause:** The `containerEnv` block in `devcontainer.json` did not propagate, or the variable name is wrong.

**Fix:** Open [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) and confirm the `"containerEnv"` block includes `"NPM_CONFIG_REGISTRY"` pointing to the Artifactory NPM URL.

---

### Container builds but Python cannot import packages

**Symptom:** `ModuleNotFoundError` for standard packages like `requests` or `numpy`

**Cause:** The `post-create.sh` step that copies `pip.conf` failed silently, or the packages were never installed.

**Fix:**
```bash
pip config list                  # Confirm index is pointing to Artifactory
pip install <package-name>       # Reinstall manually if needed
```

---

### Yarn GPG error during Dockerfile build

**Symptom:** `The following signatures couldn't be verified because the public key is not available`

**Cause:** Some base images ship with a broken Yarn apt source list entry.

**Fix:** This is already handled in the [Dockerfile](.devcontainer/dockerfile) by removing the broken source list before running `apt-get update`. No user action needed — if you see this error, ensure you are using the Dockerfile in this repo and not an older local copy.

---

### VS Code does not prompt to reopen in container

**Fix:**
1. Ensure the Dev Containers extension is installed and enabled
2. Confirm Docker Engine is running: `docker info`
3. Open the Command Palette: `F1 → Dev Containers: Reopen in Container`

---

## 13. FAQ

**Q: Can I use this container offline?**
No. All images, packages, and registry access require the Rio Tinto network or VPN. Once the container image is cached locally by Docker, you can reopen an existing container offline — but you cannot build from scratch or run `pip install`/`npm install` without network access.

---

**Q: Why is the base image on Artifactory instead of Docker Hub?**
Rio Tinto's network policy routes all external traffic through Zscaler TLS inspection. Using an Artifactory mirror means the image pull is governed by the same internal trust store and access controls as everything else, and does not require special Docker-level certificate workarounds.


---

**Q: Do I need to re-add the certificates every time I rebuild?**
No. As long as the `.crt` files remain in `.devcontainer/` on your local machine, they are available to Docker on every rebuild. You only need to re-obtain them if the certificates are rotated by Rio Tinto IT.

---

**Q: Can I add my own Python packages permanently?**
Yes. Add a `pip install <package>` line to [`post-create.sh`](.devcontainer/post-create.sh) and rebuild the container. For a more structured approach, add a `requirements.txt` to the repo root and have `post-create.sh` run `pip install -r requirements.txt`.

---

**Q: Why does the Dockerfile install Node.js if this is a Python project?**
Node.js is required by the GitHub Copilot CLI (`@github/copilot` npm package) and may be needed by other tooling. It adds minimal overhead and ensures the CLI works in the Dockerfile build path as well as the pre-built image path.

---

**Q: What is `set -e` in `post-create.sh`?**
It tells bash to exit immediately if any command in the script returns a non-zero exit code. This ensures errors are visible as build failures rather than being silently skipped and causing confusing behaviour later.

---

*Last updated: February 2026*
