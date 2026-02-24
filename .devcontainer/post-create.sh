#!/bin/bash
set -e

echo "=== Setting up development environment ==="

# Private-only sources (must be provided by environment)
PRIVATE_APT_GITHUB_CLI_REPO="${PRIVATE_APT_GITHUB_CLI_REPO:-}"
PRIVATE_NPM_REGISTRY="${PRIVATE_NPM_REGISTRY:-${NPM_CONFIG_REGISTRY:-}}"

fail_private_only() {
    echo "✗ $1"
    exit 1
}

# Copy pip.conf for private PyPI access
if [ -f "/workspaces/copilot_cli2/etc/pip.conf" ]; then
    mkdir -p ~/.config/pip
    cp /workspaces/copilot_cli2/etc/pip.conf ~/.config/pip/pip.conf
    echo "✓ pip.conf configured"
fi

# Install GitHub CLI (replaces ghcr.artifactory.riotinto.com/devcontainers/features/github-cli:1)
if ! command -v gh &> /dev/null; then
    if [ -z "$PRIVATE_APT_GITHUB_CLI_REPO" ]; then
        fail_private_only "PRIVATE_APT_GITHUB_CLI_REPO is not set (private-only mode)"
    else
        echo "Installing GitHub CLI from private APT repo..."
        echo "deb [arch=$(dpkg --print-architecture)] $PRIVATE_APT_GITHUB_CLI_REPO stable main" | sudo tee /etc/apt/sources.list.d/private-github-cli.list > /dev/null
        sudo apt-get \
            -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/private-github-cli.list \
            -o Dir::Etc::sourceparts=- \
            update
        sudo apt-get \
            -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/private-github-cli.list \
            -o Dir::Etc::sourceparts=- \
            install -y gh
        echo "✓ GitHub CLI installed"
    fi
fi

# Install GitHub Copilot CLI (replaces ghcr.artifactory.riotinto.com/devcontainers/features/copilot-cli:1)
if ! command -v github-copilot-cli &> /dev/null; then
    if [ -z "$PRIVATE_NPM_REGISTRY" ]; then
        fail_private_only "PRIVATE_NPM_REGISTRY or NPM_CONFIG_REGISTRY is not set (private-only mode)"
    else
        echo "Installing GitHub Copilot CLI from private NPM registry..."
        npm config set registry "$PRIVATE_NPM_REGISTRY"
        npm install -g @githubnext/github-copilot-cli --registry "$PRIVATE_NPM_REGISTRY"
        echo "✓ GitHub Copilot CLI installed"
    fi
fi

# Install Python requirements if they exist
if [ -f "/workspaces/copilot_cli2/requirements.txt" ]; then
    if [ ! -f "$HOME/.config/pip/pip.conf" ]; then
        fail_private_only "pip.conf is required for private-only Python installs"
    fi
    pip install -r /workspaces/copilot_cli2/requirements.txt
    echo "✓ Python requirements installed"
fi

echo "=== Container ready! ==="