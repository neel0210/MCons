#!/bin/bash
# ==============================================================================
# MCons Installer & Updater for macOS
#
# One-liner to install / update:
#   curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash
# ==============================================================================
set -euo pipefail

REPO="neel0210/MCons"
APP_NAME="MCons"
TARGET_DIR="/Applications"

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}━━━ 🎨 MCons macOS Installer ━━━${RESET}"
echo ""

# ─── Check OS ─────────────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Darwin" ]; then
    echo -e "${RED}❌ Error: MCons is only supported on macOS.${RESET}"
    exit 1
fi

# ─── Destination directory ───────────────────────────────────────────────────
if [ ! -w "${TARGET_DIR}" ]; then
    TARGET_DIR="${HOME}/Applications"
    mkdir -p "${TARGET_DIR}"
fi
TARGET_APP="${TARGET_DIR}/${APP_NAME}.app"

# ─── Stop running instance ───────────────────────────────────────────────────
if pgrep -x "${APP_NAME}" &>/dev/null; then
    echo -e "${CYAN}▸${RESET} Closing running instance of ${APP_NAME}..."
    pkill -x "${APP_NAME}" 2>/dev/null || true
    sleep 0.5
fi

# ─── Fetch latest release metadata ───────────────────────────────────────────
echo -e "${CYAN}▸${RESET} Checking latest release from GitHub..."
RELEASE_JSON=$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG_NAME=$(echo "${RELEASE_JSON}" | grep -m1 '"tag_name":' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')
DOWNLOAD_URL=$(echo "${RELEASE_JSON}" | grep -m1 '"browser_download_url":' | sed -E 's/.*"browser_download_url":[[:space:]]*"([^"]+)".*/\1/')

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
    echo -e "${YELLOW}⚠️  Could not parse latest release API. Using fallback URL...${RESET}"
    TAG_NAME="latest"
    DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/MCons-v1.0.2-release.zip"
fi

echo -e "${CYAN}▸${RESET} Found version: ${BOLD}${TAG_NAME}${RESET}"

# ─── Download ────────────────────────────────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

TMP_ZIP="${TMP_DIR}/MCons.zip"
echo -e "${CYAN}▸${RESET} Downloading MCons (${TAG_NAME})..."
curl -# -fSL -o "${TMP_ZIP}" "${DOWNLOAD_URL}"

# ─── Extract & Install ───────────────────────────────────────────────────────
echo -e "${CYAN}▸${RESET} Extracting into ${TARGET_DIR}..."
if command -v ditto &>/dev/null; then
    ditto -x -k "${TMP_ZIP}" "${TMP_DIR}"
else
    unzip -q -o "${TMP_ZIP}" -d "${TMP_DIR}"
fi

EXTRACTED_APP="${TMP_DIR}/${APP_NAME}.app"
if [ ! -d "${EXTRACTED_APP}" ]; then
    EXTRACTED_APP=$(find "${TMP_DIR}" -name "${APP_NAME}.app" -type d | head -n 1 || true)
fi

if [ -z "${EXTRACTED_APP}" ] || [ ! -d "${EXTRACTED_APP}" ]; then
    echo -e "${RED}❌ Error: Failed to find ${APP_NAME}.app in release archive.${RESET}"
    exit 1
fi

rm -rf "${TARGET_APP}"
cp -R "${EXTRACTED_APP}" "${TARGET_APP}"

# ─── Remove Gatekeeper Quarantine ────────────────────────────────────────────
echo -e "${CYAN}▸${RESET} Removing macOS Gatekeeper quarantine..."
xattr -cr "${TARGET_APP}" 2>/dev/null || true

# ─── Success & Launch ────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✅ MCons ${TAG_NAME} installed successfully!${RESET}"
echo -e "   Location: ${TARGET_APP}"
echo ""
echo -e "${CYAN}▸${RESET} Launching MCons..."
open "${TARGET_APP}"
echo ""
