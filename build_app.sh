#!/bin/bash
# build_app.sh — Advanced build, package & run script for MCons
#
# Usage:
#   ./build_app.sh                  Build release .app bundle
#   ./build_app.sh --debug          Build debug .app bundle
#   ./build_app.sh --run            Build release and launch
#   ./build_app.sh --debug --run    Build debug and launch
#   ./build_app.sh --clean          Full clean (SPM cache + output)
#   ./build_app.sh --stop           Stop running instances only
#   ./build_app.sh --zip            Build release + create .zip archive
#   ./build_app.sh --info           Print bundle metadata without building
#   ./build_app.sh --help           Show this help
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
APP_NAME="MCons"
BUNDLE_ID="com.neel0210.mcons"
EXECUTABLE_NAME="MCons"
VERSION="1.0.4"
BUILD_NUMBER="1"
MIN_MACOS="14.0"
COPYRIGHT="Copyright © 2026 Neel0210. All rights reserved."
CATEGORY="public.app-category.utilities"

# Derive build number from GITHUB_RUN_NUMBER if in CI, or git commit count
if [ -n "${GITHUB_RUN_NUMBER:-}" ]; then
    BUILD_NUMBER="${GITHUB_RUN_NUMBER}"
    GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    GIT_DIRTY=""
elif command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
    GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    GIT_DIRTY=""
    if ! git diff --quiet 2>/dev/null; then
        GIT_DIRTY="-dirty"
    fi
else
    BUILD_NUMBER="1"
    GIT_HASH="unknown"
    GIT_BRANCH="unknown"
    GIT_DIRTY=""
fi

OUTPUT_DIR="output"
APP_DIR="${OUTPUT_DIR}/${APP_NAME}.app"

# Parse flags
BUILD_CONFIG="release"
DO_RUN=false
DO_CLEAN=false
DO_STOP_ONLY=false
DO_ZIP=false
DO_INFO=false
DO_CI_BETA=false
DO_CI_PROD=false
SHOW_HELP=false

for arg in "$@"; do
    case "$arg" in
        --debug)        BUILD_CONFIG="debug" ;;
        --run)          DO_RUN=true ;;
        --clean)        DO_CLEAN=true ;;
        --stop)         DO_STOP_ONLY=true ;;
        --zip)          DO_ZIP=true ;;
        --info)         DO_INFO=true ;;
        --ci|--ci-beta) DO_CI_BETA=true ;;
        --ci-prod)      DO_CI_PROD=true ;;
        --help|-h)      SHOW_HELP=true ;;
        *)
            echo "❌ Unknown flag: $arg"
            echo "   Run './build_app.sh --help' for usage."
            exit 1
            ;;
    esac
done

BUILD_DIR=".build/${BUILD_CONFIG}"

# ─── Color helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

log()     { echo -e "${CYAN}▸${RESET} $*"; }
success() { echo -e "${GREEN}✅ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  $*${RESET}"; }
fail()    { echo -e "${RED}❌ $*${RESET}"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}"; }
dim()     { echo -e "${DIM}$*${RESET}"; }

# ─── Help ────────────────────────────────────────────────────────────────────
if $SHOW_HELP; then
    echo ""
    echo -e "${BOLD}MCons Build Script${RESET}"
    echo ""
    echo "Usage: ./build_app.sh [flags]"
    echo ""
    echo "Flags:"
    echo "  --debug      Build in debug mode (default: release)"
    echo "  --run        Launch the app after building"
    echo "  --clean      Nuke .build/ and output/ before building"
    echo "  --stop       Stop running MCons instances (no build)"
    echo "  --zip        Create output/MCons.app.zip after building"
    echo "  --info       Print build metadata without building"
    echo "  --ci-beta    Trigger GitHub Actions Beta workflow"
    echo "  --ci-prod    Trigger GitHub Actions Production workflow"
    echo "  --help, -h   Show this help"
    echo ""
    echo "Combine flags freely:"
    echo "  ./build_app.sh --debug --run --clean"
    echo "  ./build_app.sh --zip"
    echo "  ./build_app.sh --ci-beta"
    echo ""
    exit 0
fi

# ─── Stop running instances ─────────────────────────────────────────────────
stop_running() {
    local pids
    pids=$(pgrep -x "${EXECUTABLE_NAME}" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log "Stopping running instance(s) of ${APP_NAME}..."
        kill $pids 2>/dev/null || true
        sleep 0.5
        # Force kill if still alive
        pids=$(pgrep -x "${EXECUTABLE_NAME}" 2>/dev/null || true)
        if [ -n "$pids" ]; then
            warn "Force killing remaining processes..."
            kill -9 $pids 2>/dev/null || true
            sleep 0.3
        fi
        success "Stopped."
    else
        dim "No running instance found."
    fi
}

if $DO_STOP_ONLY; then
    stop_running
    exit 0
fi

# ─── Info ────────────────────────────────────────────────────────────────────
print_info() {
    header "Build Metadata"
    echo "  App:         ${APP_NAME}"
    echo "  Bundle ID:   ${BUNDLE_ID}"
    echo "  Version:     ${VERSION} (${BUILD_NUMBER})"
    echo "  Min macOS:   ${MIN_MACOS}"
    echo "  Git:         ${GIT_BRANCH}@${GIT_HASH}${GIT_DIRTY}"
    echo "  Config:      ${BUILD_CONFIG}"
    echo "  Output:      ${APP_DIR}"
    echo ""
}

if $DO_INFO; then
    print_info
    exit 0
fi

# ─── Trigger GitHub Actions CI ───────────────────────────────────────────────
trigger_ci() {
    local build_type="$1"
    header "GitHub Actions CI Dispatch"
    log "Build Type: ${BOLD}${build_type}${RESET}"
    log "Branch:     ${BOLD}${GIT_BRANCH}${RESET}"

    if command -v gh &>/dev/null; then
        log "Dispatching via GitHub CLI (gh)..."
        gh workflow run build.yml --ref "${GIT_BRANCH}" -f build_type="${build_type}"
        success "Dispatched! Monitor with: gh run list --workflow=build.yml"
    else
        local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
        if [ -z "$token" ]; then
            fail "GitHub CLI (gh) not installed and GITHUB_TOKEN not set.\n   Option 1: brew install gh && gh auth login\n   Option 2: export GITHUB_TOKEN='ghp_xxx' and rerun."
        fi
        log "Dispatching via GitHub REST API..."
        local repo="neel0210/MCons"
        local response
        response=$(curl -s -w "%{http_code}" -o /tmp/gh_dispatch_response.json \
            -X POST \
            -H "Authorization: token ${token}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${repo}/actions/workflows/build.yml/dispatches" \
            -d "{\"ref\":\"${GIT_BRANCH}\",\"inputs\":{\"build_type\":\"${build_type}\"}}")

        if [ "$response" = "204" ]; then
            success "GitHub Actions workflow dispatched successfully!"
        else
            cat /tmp/gh_dispatch_response.json 2>/dev/null || true
            fail "GitHub API returned HTTP ${response}"
        fi
    fi
}

if $DO_CI_BETA; then
    trigger_ci "Test Build (Beta)"
    exit 0
fi

if $DO_CI_PROD; then
    trigger_ci "Production Build"
    exit 0
fi

# ─── Clean ───────────────────────────────────────────────────────────────────
if $DO_CLEAN; then
    header "Cleaning"
    log "Removing .build/ and output/..."
    rm -rf .build/ "${OUTPUT_DIR}/"
    success "Clean complete."
fi

# ─── Build ───────────────────────────────────────────────────────────────────
stop_running
print_info

header "Building (${BUILD_CONFIG})"

BUILD_START=$(date +%s)

if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release 2>&1
else
    swift build 2>&1
fi

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

success "Swift build complete (${BUILD_DURATION}s)"

# ─── Package .app bundle ────────────────────────────────────────────────────
header "Packaging .app Bundle"

# Verify binary exists
BINARY_PATH="${BUILD_DIR}/${EXECUTABLE_NAME}"
[ -f "$BINARY_PATH" ] || fail "Binary not found at ${BINARY_PATH}"

# Clean previous output
rm -rf "${OUTPUT_DIR}/"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
log "Copying binary..."
cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"

# Copy SPM resource bundle
RESOURCE_BUNDLE=$(find "${BUILD_DIR}" -name "MCons_MCons.bundle" -type d 2>/dev/null | head -1 || true)
if [ -n "$RESOURCE_BUNDLE" ]; then
    log "Copying SPM resource bundle..."
    cp -R "$RESOURCE_BUNDLE" "${APP_DIR}/Contents/Resources/"
fi

# Copy IconPacks
if [ -d "MCons/Resources/IconPacks" ]; then
    log "Copying IconPacks..."
    cp -R "MCons/Resources/IconPacks" "${APP_DIR}/Contents/Resources/"
fi

# Copy AppIcon
if [ -f "MCons/Resources/AppIcon.icns" ]; then
    log "Copying AppIcon.icns..."
    cp "MCons/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

# Strip .DS_Store files from bundle
find "${APP_DIR}" -name ".DS_Store" -delete 2>/dev/null || true

# Generate Info.plist
log "Generating Info.plist..."
cat > "${APP_DIR}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>NSHumanReadableCopyright</key>
    <string>${COPYRIGHT}</string>
    <key>LSApplicationCategoryType</key>
    <string>${CATEGORY}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>MCBuildGitHash</key>
    <string>${GIT_HASH}${GIT_DIRTY}</string>
    <key>MCBuildGitBranch</key>
    <string>${GIT_BRANCH}</string>
    <key>MCBuildConfig</key>
    <string>${BUILD_CONFIG}</string>
</dict>
</plist>
PLIST

# PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# ─── Code Signing ────────────────────────────────────────────────────────────
header "Code Signing"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
ENTITLEMENTS_ARGS=()
if [ -f "MCons/Resources/MCons.entitlements" ]; then
    ENTITLEMENTS_ARGS=(--entitlements "MCons/Resources/MCons.entitlements")
fi

log "Signing bundle with identity: ${SIGN_IDENTITY}..."
codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${ENTITLEMENTS_ARGS[@]}" "${APP_DIR}"

log "Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
success "Code signature valid & verified."

# ─── Bundle stats ────────────────────────────────────────────────────────────
BINARY_SIZE=$(du -sh "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}" | awk '{print $1}')
BUNDLE_SIZE=$(du -sh "${APP_DIR}" | awk '{print $1}')
ICON_PACK_COUNT=$(find "${APP_DIR}/Contents/Resources/IconPacks" -name "metadata.json" 2>/dev/null | wc -l | tr -d ' ')
ICON_COUNT=$(find "${APP_DIR}/Contents/Resources/IconPacks" -name "*.svg" 2>/dev/null | wc -l | tr -d ' ')

header "Build Summary"
echo ""
echo -e "  ${BOLD}App:${RESET}         ${APP_NAME} v${VERSION} (${BUILD_NUMBER})"
echo -e "  ${BOLD}Config:${RESET}      ${BUILD_CONFIG}"
echo -e "  ${BOLD}Git:${RESET}         ${GIT_BRANCH}@${GIT_HASH}${GIT_DIRTY}"
echo -e "  ${BOLD}Binary:${RESET}      ${BINARY_SIZE}"
echo -e "  ${BOLD}Bundle:${RESET}      ${BUNDLE_SIZE}"
echo -e "  ${BOLD}Icon Packs:${RESET}  ${ICON_PACK_COUNT} packs, ${ICON_COUNT} SVG icons"
echo -e "  ${BOLD}Build Time:${RESET}  ${BUILD_DURATION}s"
echo -e "  ${BOLD}Output:${RESET}      ${APP_DIR}"
echo ""
success "App bundle ready."

# ─── Zip ─────────────────────────────────────────────────────────────────────
if $DO_ZIP; then
    header "Creating ZIP Archive"
    ZIP_NAME="${APP_NAME}-v${VERSION}-${BUILD_CONFIG}.zip"
    rm -f "${OUTPUT_DIR}/${ZIP_NAME}"

    # Generate helper unquarantine & launcher script
    COMMAND_SCRIPT="${OUTPUT_DIR}/Open_MCons.command"
    cat > "${COMMAND_SCRIPT}" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="${DIR}/MCons.app"

echo "========================================"
echo "          🔓 Unlocking MCons            "
echo "========================================"
echo ""

if [ -d "$APP" ]; then
    echo "Clearing Gatekeeper quarantine..."
    xattr -cr "$APP" 2>/dev/null || true
    echo "✅ MCons unlocked successfully!"
    echo "🚀 Launching MCons..."
    open "$APP"
elif [ -d "/Applications/MCons.app" ]; then
    echo "Clearing Gatekeeper quarantine from /Applications/MCons.app..."
    xattr -cr "/Applications/MCons.app" 2>/dev/null || true
    echo "✅ MCons unlocked successfully!"
    echo "🚀 Launching MCons..."
    open "/Applications/MCons.app"
else
    echo "❌ MCons.app not found in current directory or /Applications."
    echo "   Place MCons.app in the same folder as this script."
fi

sleep 1
exit 0
EOF
    chmod +x "${COMMAND_SCRIPT}"

    (cd "${OUTPUT_DIR}" && zip -r -y -q "${ZIP_NAME}" "${APP_NAME}.app" "Open_MCons.command")
    ZIP_SIZE=$(du -sh "${OUTPUT_DIR}/${ZIP_NAME}" | awk '{print $1}')
    success "Archive: ${OUTPUT_DIR}/${ZIP_NAME} (${ZIP_SIZE})"
fi

# ─── Run ─────────────────────────────────────────────────────────────────────
if $DO_RUN; then
    header "Launching"
    log "Opening ${APP_DIR}..."
    open "${APP_DIR}"
    success "App launched."
fi
