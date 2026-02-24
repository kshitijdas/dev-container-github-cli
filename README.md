# Dev Container Setup Guide

A step-by-step guide to setting up and using this repository's dev container on the Rio Tinto corporate network for the Copilot CLI Session.
---

## Table of Contents

1. [What Is a Dev Container?](#1-what-is-a-dev-container)
2. [Prerequisites](#2-prerequisites)
3. [Step-by-Step Setup](#3-step-by-step-setup)
4. [Verifying the Environment](#4-verifying-the-environment)
5. [Troubleshooting](#5-troubleshooting)
6. [FAQ](#6-faq)

---

## 1. What Is a Dev Container?

A dev container is a full development environment defined as code. When you open this repository in VS Code, Docker pulls a pre-built container image with the correct Python version, GitHub CLI, GitHub Copilot CLI, and Node.js already included — every developer on the team gets an identical setup regardless of their host machine.

---

## 2. Prerequisites

You need **three things** before opening the container.

### 2.1 Docker Desktop / Docker Engine

Docker must be installed and running on your machine before you open VS Code.

- **Windows:** Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and ensure WSL 2 integration is enabled.
- **macOS / Linux:** Docker Desktop or Docker Engine either work.

### 2.2 VS Code + Dev Containers Extension

Install the **Dev Containers** extension in VS Code:

- Extension ID: `ms-vscode-remote.remote-containers`
- On **Windows**, install the extension inside your **WSL VS Code instance**, not the Windows one.

### 2.3 Artifactory Docker Logins

The base image and dev container features are pulled from Rio Tinto's internal Artifactory registries. You must be logged in to both before building the container.

**Step 1 — Get your Artifactory token**

Follow the instructions on the internal SharePoint page to generate your Artifactory identity token:
[Artifactory — Setting up Credentials (Identity Token)](https://riotinto.sharepoint.com/sites/5059953/SitePages/Artifactory---Setting-up-Credentials-(Identity-Token).aspx)

**Step 2 — Log in to both registries**

Open a terminal (WSL terminal on Windows) and run:

```bash
docker login riotinto-docker.artifactory.riotinto.com
docker login ghcr.artifactory.riotinto.com
```

Enter your Rio Tinto username and the identity token as the password when prompted.

> You only need to do this once per machine. Docker caches the credentials.



## 3. Step-by-Step Setup

### Step 1 — Devcontainer setup

- In your project root folder create a `.devcontainer` sub folder
- Create a `devcontainer.json` file and copy this contents to it. 


```json
{
    "name": "Python 3",
    "image": "riotinto-docker.artifactory.riotinto.com/ist/tech-platforms/tech-enablement/devex/devcontainer/python",
    "features": {
        "ghcr.artifactory.riotinto.com/devcontainers/features/copilot-cli:1": {},
        "ghcr.artifactory.riotinto.com/devcontainers/features/github-cli:1": {},
        "ghcr.artifactory.riotinto.com/devcontainers/features/node:1": {
            "version": "lts"
        }
    }
}
```

What each part does:

| Key | Purpose |
|---|---|
| `image` | Pulls the approved Rio Tinto Python base image from Artifactory |
| `copilot-cli` feature | Installs GitHub Copilot CLI (`copilot`) from the Artifactory ghcr mirror |
| `github-cli` feature | Installs GitHub CLI (`gh`) from the Artifactory ghcr mirror |
| `node` feature | Installs Node.js LTS from the Artifactory ghcr mirror |


### Step 2 — Open in VS Code

```bash
code .
```

VS Code will detect the `.devcontainer/` folder and show a prompt in the bottom-right corner:

> **"Folder contains a Dev Container configuration file. Reopen in Container?"**

Click **Reopen in Container**.

Alternatively: `F1` → `Dev Containers: Reopen in Container` → Enter.

### Step 3 — Wait for the build

The first build pulls the base image and installs the three features from Artifactory. This typically takes **3–8 minutes** depending on your network connection.

Progress is shown in the VS Code terminal. Click **"show log"** in the notification to follow along in detail.

On **subsequent reopens**, Docker uses the cached image — startup takes only a few seconds.

To force a full rebuild after changing `devcontainer.json`:
```
F1 → Dev Containers: Rebuild Container
```

---

## 4. Verifying the Environment

Once the container is running, open a terminal (`Ctrl + `` ` ``) and run the checks below.

### Python

```bash
python --version     # Python 3.x.x
```

### GitHub CLI

```bash
gh --version
gh auth status       # Shows your logged-in GitHub account
```

If not authenticated:
```bash
gh auth login
```
Follow the prompts — use HTTPS and authenticate via browser or PAT.

### GitHub Copilot CLI

```bash
copilot --version
```

To authenticate:
```bash
copilot auth login
```

### Node.js

```bash
node --version       # v20.x.x or similar LTS
npm --version
```

---

## 5. Troubleshooting

### Cannot pull base image — `pull access denied` or `no such host`

**Cause:** Docker is not logged in to the Artifactory registry, or you are off the Rio Tinto network / VPN.

**Fix:**
```bash
docker login riotinto-docker.artifactory.riotinto.com
docker login ghcr.artifactory.riotinto.com
```
Then rebuild: `F1 → Dev Containers: Rebuild Container`.

---

### VS Code does not prompt to reopen in container

**Fix:**
1. Confirm the Dev Containers extension is installed and enabled (in WSL on Windows)
2. Confirm Docker is running: `docker info`
3. Manually trigger: `F1 → Dev Containers: Reopen in Container`

---

### Feature installation fails during build

**Cause:** The `ghcr.artifactory.riotinto.com` registry login is missing or expired.

**Fix:**
```bash
docker login ghcr.artifactory.riotinto.com
```
Then rebuild the container.

---

## 6. FAQ

**Q: Can I use this container offline?**
Once the image is cached by Docker locally, you can reopen the existing container offline. You cannot do a fresh build or pull updated images without access to Artifactory.

---

**Q: Why are images pulled from Artifactory instead of Docker Hub / ghcr.io?**
Rio Tinto's network routes all external HTTPS traffic through Zscaler TLS inspection. Artifactory acts as a governed internal mirror, avoiding certificate trust issues and ensuring all artefacts go through internal access controls.

---

**Q: Do I need to log in to Docker registries every time?**
No. Docker caches credentials after the first login. You only need to re-login if your Artifactory token expires or is rotated.

---

**Q: Can I add Python packages to the container?**
Yes. Add a `requirements.txt` to the repo root and a `postCreateCommand` in `devcontainer.json`:
```json
"postCreateCommand": "pip install -r requirements.txt"
```
Then rebuild the container.

---

*Last updated: February 2026*