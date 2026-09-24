#!/usr/bin/env bash
# ============================================================
# get.sh - one-line remote installer for storage-monitor
#
#   curl -fsSL https://raw.githubusercontent.com/<YOUR_GH_USER>/storage-monitor/main/dist/get.sh | bash
#
# Works on Linux, macOS, and WSL (which is just Linux).
# Downloads the latest tagged release tarball from GitHub,
# extracts it, and runs the bundled install.sh with sudo.
# ============================================================

set -euo pipefail

REPO="YOUR_GH_USER/storage-monitor"   # <-- change this after publishing
TMP_DIR="$(mktemp -d)"

OS="$(uname -s)"
if [[ "$OS" != "Linux" && "$OS" != "Darwin" ]]; then
    echo "Unsupported OS: $OS (Linux/macOS/WSL only)."
    exit 1
fi

echo "==> Fetching latest storage-monitor release..."
TARBALL_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tarball_url":' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$TARBALL_URL" ]]; then
    echo "Could not find a release for ${REPO}. Falling back to the main branch..."
    TARBALL_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
fi

echo "==> Downloading ${TARBALL_URL}"
curl -fsSL "$TARBALL_URL" -o "${TMP_DIR}/storage-monitor.tar.gz"

echo "==> Extracting..."
mkdir -p "${TMP_DIR}/extracted"
tar -xzf "${TMP_DIR}/storage-monitor.tar.gz" -C "${TMP_DIR}/extracted" --strip-components=1

echo "==> Installing (you may be prompted for your password)..."
cd "${TMP_DIR}/extracted"
chmod +x install.sh bin/*.sh
sudo ./install.sh

rm -rf "${TMP_DIR}"

echo ""
echo "Done. Try: storage-monitor"
