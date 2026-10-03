#!/bin/bash
# build.sh — Cross-platform build, package, test & CI automation for MCons
# Supports: macOS (native), Linux & Windows (validation, CI dispatch, artifact download)
#
# Usage:
#   ./build.sh                      Build release .app bundle (macOS)
#   ./build.sh --debug              Build debug .app bundle
#   ./build.sh --universal          Build Universal 2 (arm64 + x86_64) bundle
#   ./build.sh --dmg                Create .dmg disk image with /Applications symlink
#   ./build.sh --zip                Create .zip release archive
#   ./build.sh --install            Install directly to /Applications/MCons.app
#   ./build.sh --notarize           Submit bundle to Apple Notary Service & staple
#   ./build.sh --test               Run swift test suite before building
#   ./build.sh --validate           Validate all IconPacks metadata & SVG assets
#   ./build.sh --run                Build and launch app
#   ./build.sh --clean              Clean .build/ and output/ directories
#   ./build.sh --stop               Stop running MCons instances
#   ./build.sh --version <ver>      Override version string
#   ./build.sh --ci-beta            Trigger GitHub Actions Beta build
#   ./build.sh --ci-prod            Trigger GitHub Actions Production build
#   ./build.sh --download           Download latest release artifact from GitHub
#   ./build.sh --info               Print build metadata without building
#   ./build.sh --help               Show this help
set -euo pipefail

# ─── Platform Detection ──────────────────────────────────────────────────────
OS_NAME="$(uname -s 2>/dev/null || echo "Unknown")"
case "${OS_NAME}" in
    Darwin*)                            PLATFORM="macos" ;;
    Linux*)                             PLATFORM="linux" ;;
    CYGWIN*|MINGW*|MSYS*|Windows_NT*)   PLATFORM="windows" ;;
    *)                                  PLATFORM="unknown" ;;
esac

# ─── Configuration ───────────────────────────────────────────────────────────
APP_NAME="MCons"
BUNDLE_ID="com.neel0210.mcons"
EXECUTABLE_NAME="MCons"
MIN_MACOS="14.0"
COPYRIGHT="Copyright © 2026 Neel0210. All rights reserved."
CATEGORY="public.app-category.utilities"
REPO="neel0210/MCons"

# Detect version: flag > git tag > default 1.0.4
USER_VERSION=""
GIT_TAG="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
VERSION="${GIT_TAG:-1.0.4}"

# Build number
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

# CPU Cores for parallel build
NUM_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "${NUMBER_OF_PROCESSORS:-4}")

# Parse flags
BUILD_CONFIG="release"
DO_RUN=false
DO_CLEAN=false
DO_STOP_ONLY=false
DO_ZIP=false
DO_DMG=false
DO_UNIVERSAL=false
DO_INSTALL=false
DO_NOTARIZE=false
DO_TEST=false
DO_VALIDATE=false
DO_INFO=false
DO_CI_BETA=false
DO_CI_PROD=false
DO_DOWNLOAD=false
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)        BUILD_CONFIG="debug"; shift ;;
        --release)      BUILD_CONFIG="release"; shift ;;
        --universal)    DO_UNIVERSAL=true; shift ;;
        --dmg)          DO_DMG=true; shift ;;
        --zip)          DO_ZIP=true; shift ;;
        --install)      DO_INSTALL=true; shift ;;
        --notarize)     DO_NOTARIZE=true; shift ;;
        --test)         DO_TEST=true; shift ;;
        --validate)     DO_VALIDATE=true; shift ;;
        --run)          DO_RUN=true; shift ;;
        --clean)        DO_CLEAN=true; shift ;;
        --stop)         DO_STOP_ONLY=true; shift ;;
        --info)         DO_INFO=true; shift ;;
        --ci|--ci-beta) DO_CI_BETA=true; shift ;;
        --ci-prod)      DO_CI_PROD=true; shift ;;
        --download)     DO_DOWNLOAD=true; shift ;;
        --version)
            if [ -n "${2:-}" ] && [[ "$2" != --* ]]; then
                USER_VERSION="$2"
                VERSION="$2"
                shift 2
            else
                echo "❌ --version requires an argument (e.g. --version 1.0.5)"
                exit 1
            fi
            ;;
        --jobs|-j)
            if [ -n "${2:-}" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                NUM_JOBS="$2"
                shift 2
            else
                echo "❌ -j/--jobs requires a positive integer"
                exit 1
            fi
            ;;
        --help|-h)      SHOW_HELP=true; shift ;;
        *)
            echo "❌ Unknown flag: $1"
            echo "   Run './build.sh --help' for usage."
            exit 1
            ;;
    esac
done

BUILD_DIR=".build/${BUILD_CONFIG}"

# ─── Color Helpers ───────────────────────────────────────────────────────────
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
    echo -e "${BOLD}MCons Build & Packaging Automation${RESET}"
    echo -e "${DIM}Platform: ${PLATFORM} (${OS_NAME}) | Host Cores: ${NUM_JOBS}${RESET}"
    echo ""
    echo "Usage: ./build.sh [flags]"
    echo ""
    echo "Build & Packaging Flags:"
    echo "  --release       Build release .app bundle (default)"
    echo "  --debug         Build debug .app bundle"
    echo "  --universal     Build Universal 2 (arm64 + x86_64) binary via lipo"
    echo "  --dmg           Create macOS .dmg disk image with /Applications symlink"
    echo "  --zip           Create .zip release archive with Gatekeeper unlock script"
    echo "  --install       Install directly to /Applications/MCons.app"
    echo "  --notarize      Submit bundle to Apple Notary Service & staple (macOS)"
    echo "  --test          Run Swift test suite before building"
    echo "  --validate      Validate all IconPacks metadata & SVG assets"
    echo "  --run           Launch the app after building"
    echo ""
    echo "Project & CI Flags:"
    echo "  --clean         Nuke .build/ and output/ before building"
    echo "  --stop          Stop running MCons instances (no build)"
    echo "  --version <v>   Override bundle version (default: ${VERSION})"
    echo "  -j, --jobs <n>  Compiler concurrency threads (default: ${NUM_JOBS})"
    echo "  --info          Print build metadata without building"
    echo "  --ci-beta       Trigger GitHub Actions Beta workflow"
    echo "  --ci-prod       Trigger GitHub Actions Production workflow"
    echo "  --download      Download latest release artifact from GitHub into output/"
    echo "  --help, -h      Show this help"
    echo ""
    echo "Examples:"
    echo "  ./build.sh --universal --zip --dmg"
    echo "  ./build.sh --validate"
    echo "  ./build.sh --ci-beta"
    echo ""
    exit 0
fi

# ─── Icon Pack Validation ────────────────────────────────────────────────────
validate_icon_packs() {
    header "Validating Icon Packs"
    local pack_dir="MCons/Resources/IconPacks"
    [ -d "$pack_dir" ] || fail "IconPacks directory not found at ${pack_dir}"

    local valid_packs=0
    local total_icons=0
    local has_errors=false

    for dir in "$pack_dir"/*; do
        [ -d "$dir" ] || continue
        local pack_name
        pack_name="$(basename "$dir")"
        local meta_file="${dir}/metadata.json"

        if [ ! -f "$meta_file" ]; then
            warn "Pack '${pack_name}' missing metadata.json"
            has_errors=true
            continue
        fi

        # Check required fields in metadata.json
        if ! grep -q '"id"' "$meta_file" || ! grep -q '"name"' "$meta_file" || ! grep -q '"emoji"' "$meta_file"; then
            warn "Pack '${pack_name}' metadata.json missing required keys (id, name, emoji)"
            has_errors=true
            continue
        fi

        local svg_count
        svg_count=$(find "$dir" -maxdepth 1 -name "*.svg" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$pack_name" = "macos-native-plus" ]; then
            valid_packs=$((valid_packs + 1))
            echo -e "  ${GREEN}✓${RESET} ${pack_name}: ${DIM}CoreGraphics Vector (Programmatic)${RESET}"
            continue
        fi
        if [ "$svg_count" -eq 0 ]; then
            warn "Pack '${pack_name}' contains 0 SVG icons"
            has_errors=true
            continue
        fi

        valid_packs=$((valid_packs + 1))
        total_icons=$((total_icons + svg_count))
        echo -e "  ${GREEN}✓${RESET} ${pack_name}: ${BOLD}${svg_count}${RESET} icons"
    done

    echo ""
    if $has_errors; then
        warn "Icon pack validation completed with warnings."
    else
        success "All ${valid_packs} icon packs valid! Total: ${BOLD}${total_icons}${RESET} SVG icons."
    fi
}

if $DO_VALIDATE; then
    validate_icon_packs
    exit 0
fi

# ─── Stop Running Instances ──────────────────────────────────────────────────
stop_running() {
    if [ "$PLATFORM" = "macos" ]; then
        local pids
        pids=$(pgrep -x "${EXECUTABLE_NAME}" 2>/dev/null || true)
        if [ -n "$pids" ]; then
            log "Stopping running instance(s) of ${APP_NAME}..."
            kill $pids 2>/dev/null || true
            sleep 0.5
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
    elif [ "$PLATFORM" = "windows" ]; then
        if tasklist 2>/dev/null | grep -i "${EXECUTABLE_NAME}" &>/dev/null; then
            taskkill //F //IM "${EXECUTABLE_NAME}.exe" 2>/dev/null || true
            success "Stopped."
        else
            dim "No running instance found."
        fi
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
    echo "  Platform:    ${PLATFORM} (${OS_NAME})"
    echo "  Min macOS:   ${MIN_MACOS}"
    echo "  Git:         ${GIT_BRANCH}@${GIT_HASH}${GIT_DIRTY}"
    echo "  Config:      ${BUILD_CONFIG}"
    echo "  Concurrency: ${NUM_JOBS} cores"
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
            fail "GitHub CLI (gh) not installed and GITHUB_TOKEN not set.\n   Option 1: brew install gh (or choco install gh) && gh auth login\n   Option 2: export GITHUB_TOKEN='ghp_xxx' and rerun."
        fi
        log "Dispatching via GitHub REST API..."
        local response
        local tmp_resp="/tmp/gh_dispatch_response.json"
        [ -d "/tmp" ] || tmp_resp="${OUTPUT_DIR}/gh_dispatch_response.json"
        mkdir -p "$(dirname "$tmp_resp")"

        response=$(curl -s -w "%{http_code}" -o "$tmp_resp" \
            -X POST \
            -H "Authorization: token ${token}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${REPO}/actions/workflows/build.yml/dispatches" \
            -d "{\"ref\":\"${GIT_BRANCH}\",\"inputs\":{\"build_type\":\"${build_type}\"}}")

        if [ "$response" = "204" ]; then
            success "GitHub Actions workflow dispatched successfully!"
        else
            cat "$tmp_resp" 2>/dev/null || true
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

# ─── Download Latest Release ─────────────────────────────────────────────────
download_release() {
    header "Downloading Latest Release"
    mkdir -p "${OUTPUT_DIR}"
    log "Querying GitHub API for latest release..."
    local release_json
    release_json=$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest" || true)
    local dl_url
    dl_url=$(echo "${release_json}" | grep -m1 '"browser_download_url":' | sed -E 's/.*"browser_download_url":[[:space:]]*"([^"]+)".*/\1/' || true)
    local tag_name
    tag_name=$(echo "${release_json}" | grep -m1 '"tag_name":' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/' || true)

    if [ -z "${dl_url}" ] || [ "${dl_url}" = "null" ]; then
        warn "Could not parse release URL from API. Using default release URL..."
        tag_name="v${VERSION}"
        dl_url="https://github.com/${REPO}/releases/download/${tag_name}/MCons-${tag_name}-release.zip"
    fi

    local zip_target="${OUTPUT_DIR}/MCons-${tag_name}-release.zip"
    log "Downloading ${BOLD}${tag_name}${RESET} from: ${dl_url}"
    curl -# -fSL -o "${zip_target}" "${dl_url}"
    success "Saved artifact to ${zip_target}"
}

if $DO_DOWNLOAD; then
    download_release
    exit 0
fi

# ─── Clean ───────────────────────────────────────────────────────────────────
if $DO_CLEAN; then
    header "Cleaning"
    log "Removing .build/ and output/..."
    rm -rf .build/ "${OUTPUT_DIR}/"
    success "Clean complete."
fi

# ─── Non-macOS Platform Guard ────────────────────────────────────────────────
if [ "$PLATFORM" != "macos" ]; then
    header "Cross-Platform Build Notice"
    echo -e "${YELLOW}ℹ️  Host platform detected:${RESET} ${BOLD}${PLATFORM}${RESET} (${OS_NAME})"
    echo -e "   MCons is a native macOS application built with SwiftUI & AppKit (requires macOS 14.0+ SDK)."
    echo ""
    echo "Available actions on ${PLATFORM}:"
    echo "  1. Validate Icon Packs:      ./build.sh --validate"
    echo "  2. Dispatch CI Beta Build:    ./build.sh --ci-beta"
    echo "  3. Dispatch CI Prod Build:    ./build.sh --ci-prod"
    echo "  4. Download Latest Artifact:  ./build.sh --download"
    echo ""

    validate_icon_packs

    if [ "$PLATFORM" = "windows" ]; then
        echo ""
        log "Windows developers can also use native PowerShell: .\\build.ps1 -Help"
    fi

    exit 0
fi

# ─── Run Pre-Build Tests (macOS) ─────────────────────────────────────────────
if $DO_TEST; then
    header "Running Tests"
    log "Executing 'swift test'..."
    swift test -j "${NUM_JOBS}" 2>&1
    success "Tests passed."
fi

# ─── Build (macOS) ───────────────────────────────────────────────────────────
stop_running
print_info
validate_icon_packs

header "Building (${BUILD_CONFIG})"
BUILD_START=$(date +%s)

SWIFT_BUILD_FLAGS=(-c "${BUILD_CONFIG}" -j "${NUM_JOBS}")

if $DO_UNIVERSAL; then
    log "Building arm64 slice..."
    swift build "${SWIFT_BUILD_FLAGS[@]}" --triple arm64-apple-macosx 2>&1

    log "Building x86_64 slice..."
    swift build "${SWIFT_BUILD_FLAGS[@]}" --triple x86_64-apple-macosx 2>&1
else
    swift build "${SWIFT_BUILD_FLAGS[@]}" 2>&1
fi

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))
success "Swift build complete (${BUILD_DURATION}s)"

# ─── Package .app Bundle ────────────────────────────────────────────────────
header "Packaging .app Bundle"

# Clean previous output
rm -rf "${OUTPUT_DIR}/"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Assemble Binary
if $DO_UNIVERSAL; then
    ARM64_BIN=".build/arm64-apple-macosx/${BUILD_CONFIG}/${EXECUTABLE_NAME}"
    X86_BIN=".build/x86_64-apple-macosx/${BUILD_CONFIG}/${EXECUTABLE_NAME}"
    [ -f "$ARM64_BIN" ] || fail "arm64 slice missing at ${ARM64_BIN}"
    [ -f "$X86_BIN" ] || fail "x86_64 slice missing at ${X86_BIN}"

    log "Merging universal binary via lipo..."
    lipo -create "$ARM64_BIN" "$X86_BIN" -output "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"
    log "Universal architectures: $(lipo -archs "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}")"
else
    BINARY_PATH="${BUILD_DIR}/${EXECUTABLE_NAME}"
    [ -f "$BINARY_PATH" ] || fail "Binary not found at ${BINARY_PATH}"
    log "Copying binary..."
    cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"
fi
chmod +x "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"

# Copy SPM resource bundle
RESOURCE_BUNDLE=$(find .build -name "MCons_MCons.bundle" -type d 2>/dev/null | head -1 || true)
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

# Strip .DS_Store
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
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>${BUNDLE_ID}</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>mcons</string>
            </array>
        </dict>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Folders and Directories</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.folder</string>
                <string>public.directory</string>
                <string>com.apple.application-bundle</string>
            </array>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
        </dict>
    </array>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Apply Icon with MCons</string>
            </dict>
            <key>NSMessage</key>
            <string>applyIconFromService</string>
            <key>NSPortName</key>
            <string>${APP_NAME}</string>
            <key>NSRequiredContext</key>
            <dict/>
            <key>NSSendTypes</key>
            <array>
                <string>NSFilenamesPboardType</string>
                <string>public.file-url</string>
            </array>
        </dict>
    </array>
    <key>MCBuildGitHash</key>
    <string>${GIT_HASH}${GIT_DIRTY}</string>
    <key>MCBuildGitBranch</key>
    <string>${GIT_BRANCH}</string>
    <key>MCBuildConfig</key>
    <string>${BUILD_CONFIG}</string>
</dict>
</plist>
PLIST

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

# ─── Bundle Stats ────────────────────────────────────────────────────────────
BINARY_SIZE=$(du -sh "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}" | awk '{print $1}')
BUNDLE_SIZE=$(du -sh "${APP_DIR}" | awk '{print $1}')
ICON_PACK_COUNT=$(find "${APP_DIR}/Contents/Resources/IconPacks" -name "metadata.json" 2>/dev/null | wc -l | tr -d ' ')
ICON_COUNT=$(find "${APP_DIR}/Contents/Resources/IconPacks" -name "*.svg" 2>/dev/null | wc -l | tr -d ' ')

header "Build Summary"
echo ""
echo -e "  ${BOLD}App:${RESET}         ${APP_NAME} v${VERSION} (${BUILD_NUMBER})"
echo -e "  ${BOLD}Config:${RESET}      ${BUILD_CONFIG} $( $DO_UNIVERSAL && echo "(Universal arm64+x86_64)" || echo "" )"
echo -e "  ${BOLD}Git:${RESET}         ${GIT_BRANCH}@${GIT_HASH}${GIT_DIRTY}"
echo -e "  ${BOLD}Binary:${RESET}      ${BINARY_SIZE}"
echo -e "  ${BOLD}Bundle:${RESET}      ${BUNDLE_SIZE}"
echo -e "  ${BOLD}Icon Packs:${RESET}  ${ICON_PACK_COUNT} packs, ${ICON_COUNT} SVG icons"
echo -e "  ${BOLD}Build Time:${RESET}  ${BUILD_DURATION}s"
echo -e "  ${BOLD}Output:${RESET}      ${APP_DIR}"
echo ""
success "App bundle ready."

# ─── Zip Packaging ───────────────────────────────────────────────────────────
ZIP_NAME="${APP_NAME}-v${VERSION}-${BUILD_CONFIG}.zip"
if $DO_ZIP; then
    header "Creating ZIP Archive"
    rm -f "${OUTPUT_DIR}/${ZIP_NAME}"

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
    
    # Maintain CI alias if version differs from 1.0.4
    if [ "${VERSION}" != "1.0.4" ]; then
        cp "${OUTPUT_DIR}/${ZIP_NAME}" "${OUTPUT_DIR}/${APP_NAME}-v1.0.4-release.zip" 2>/dev/null || true
    fi

    ZIP_SIZE=$(du -sh "${OUTPUT_DIR}/${ZIP_NAME}" | awk '{print $1}')
    success "Archive: ${OUTPUT_DIR}/${ZIP_NAME} (${ZIP_SIZE})"
fi

# ─── DMG Packaging ───────────────────────────────────────────────────────────
if $DO_DMG; then
    header "Creating DMG Disk Image"
    DMG_NAME="${APP_NAME}-v${VERSION}-${BUILD_CONFIG}.dmg"
    DMG_TEMP="${OUTPUT_DIR}/dmg_temp"
    rm -rf "${DMG_TEMP}" "${OUTPUT_DIR}/${DMG_NAME}"
    mkdir -p "${DMG_TEMP}"

    log "Preparing DMG contents..."
    cp -R "${APP_DIR}" "${DMG_TEMP}/"
    ln -s /Applications "${DMG_TEMP}/Applications"

    log "Creating compressed DMG..."
    hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${OUTPUT_DIR}/${DMG_NAME}"
    rm -rf "${DMG_TEMP}"

    # Maintain CI alias if version differs from 1.0.4
    if [ "${VERSION}" != "1.0.4" ]; then
        cp "${OUTPUT_DIR}/${DMG_NAME}" "${OUTPUT_DIR}/${APP_NAME}-v1.0.4-release.dmg" 2>/dev/null || true
    fi

    DMG_SIZE=$(du -sh "${OUTPUT_DIR}/${DMG_NAME}" | awk '{print $1}')
    success "Disk Image: ${OUTPUT_DIR}/${DMG_NAME} (${DMG_SIZE})"
fi

# ─── Notarization Pipeline ───────────────────────────────────────────────────
if $DO_NOTARIZE; then
    header "Notarization Pipeline"
    NOTARY_PROFILE="${NOTARY_PROFILE:-MCons-Notary}"
    
    ARCHIVE_FOR_NOTARY="${OUTPUT_DIR}/${ZIP_NAME}"
    if [ ! -f "${ARCHIVE_FOR_NOTARY}" ]; then
        (cd "${OUTPUT_DIR}" && zip -r -y -q "${ZIP_NAME}" "${APP_NAME}.app")
    fi

    log "Submitting to Apple Notary Service (profile: ${NOTARY_PROFILE})..."
    if xcrun notarytool submit "${ARCHIVE_FOR_NOTARY}" --keychain-profile "${NOTARY_PROFILE}" --wait; then
        log "Stapling notarization ticket to ${APP_DIR}..."
        xcrun stapler staple "${APP_DIR}"
        if $DO_DMG && [ -f "${OUTPUT_DIR}/${DMG_NAME}" ]; then
            log "Stapling notarization ticket to DMG..."
            xcrun stapler staple "${OUTPUT_DIR}/${DMG_NAME}"
        fi
        success "Notarization complete & stapled."
    else
        fail "Notarization failed."
    fi
fi

# ─── Local Install ───────────────────────────────────────────────────────────
if $DO_INSTALL; then
    header "Installing to /Applications"
    INSTALL_TARGET="/Applications/${APP_NAME}.app"
    [ -w "/Applications" ] || INSTALL_TARGET="${HOME}/Applications/${APP_NAME}.app"
    mkdir -p "$(dirname "${INSTALL_TARGET}")"

    stop_running
    log "Copying to ${INSTALL_TARGET}..."
    rm -rf "${INSTALL_TARGET}"
    cp -R "${APP_DIR}" "${INSTALL_TARGET}"

    log "Removing Gatekeeper quarantine attribute..."
    xattr -cr "${INSTALL_TARGET}" 2>/dev/null || true
    success "Installed to ${INSTALL_TARGET}"
fi

# ─── Run ─────────────────────────────────────────────────────────────────────
if $DO_RUN; then
    header "Launching"
    log "Opening ${APP_DIR}..."
    open "${APP_DIR}"
    success "App launched."
fi
