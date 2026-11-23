#!/usr/bin/env bash
# ==============================================================================
# MCons — Universal High-Performance Build Script (macOS & Windows)
# ==============================================================================
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   --clean        Deep-clean all caches, targets, and derived data
#   --debug        Build unoptimized debug binaries (default: release)
#   --cli-only     Build only the CLI binary (mcons)
#   --app-only     Build only the desktop GUI app (mcons-app)
#   --no-universal macOS: skip x86_64 cross-compile, build native arch only
#   --no-dmg       macOS: skip DMG creation
#   --no-nsis      Windows: skip NSIS portable .exe packaging
#   --no-zip       Skip ZIP archive creation
#   --jobs N       Override parallel job count (default: auto-detect)
#   --verbose      Show full compiler output
#   --dry-run      Print what would be done without executing
#   -h, --help     Show this help message
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── ANSI Colors ──────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
    BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''
    BOLD=''; DIM=''; NC=''
fi

# ── Logging ──────────────────────────────────────────────────────────────────
_ts()       { date +%H:%M:%S 2>/dev/null || echo "--:--:--"; }
log_info()  { printf "${CYAN}${BOLD}[%s INFO]${NC}  %s\n" "$(_ts)" "$*"; }
log_ok()    { printf "${GREEN}${BOLD}[%s  OK ]${NC}  %s\n" "$(_ts)" "$*"; }
log_warn()  { printf "${YELLOW}${BOLD}[%s WARN]${NC}  %s\n" "$(_ts)" "$*"; }
log_error() { printf "${RED}${BOLD}[%s FAIL]${NC}  %s\n" "$(_ts)" "$*"; }
log_step()  { printf "\n${MAGENTA}${BOLD}━━━ %s ━━━${NC}\n" "$*"; }
log_dim()   { printf "${DIM}       %s${NC}\n" "$*"; }

# ── Timer ────────────────────────────────────────────────────────────────────
_TIMER_START=""
timer_start() { _TIMER_START=$(date +%s); }
timer_elapsed() {
    local end=$(date +%s)
    local diff=$(( end - _TIMER_START ))
    local m=$(( diff / 60 )) s=$(( diff % 60 ))
    if (( m > 0 )); then echo "${m}m${s}s"; else echo "${s}s"; fi
}

# ── Root directory ───────────────────────────────────────────────────────────
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# ── Defaults ─────────────────────────────────────────────────────────────────
DO_CLEAN=false
BUILD_MODE="release"
CARGO_PROFILE_FLAG="--release"
TARGET_TYPE="all"           # all | cli | app
DO_UNIVERSAL=true           # macOS: universal binary
DO_DMG=true                 # macOS: create DMG
DO_NSIS=true                # Windows: NSIS packaging
DO_ZIP=true                 # Create ZIP archives
VERBOSE=false
DRY_RUN=false
JOBS=""

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)        DO_CLEAN=true ;;
        --debug)        BUILD_MODE="debug"; CARGO_PROFILE_FLAG="" ;;
        --cli-only)     TARGET_TYPE="cli" ;;
        --app-only)     TARGET_TYPE="app" ;;
        --no-universal) DO_UNIVERSAL=false ;;
        --no-dmg)       DO_DMG=false ;;
        --no-nsis)      DO_NSIS=false ;;
        --no-zip)       DO_ZIP=false ;;
        --verbose)      VERBOSE=true ;;
        --dry-run)      DRY_RUN=true ;;
        --jobs)
            shift
            JOBS="$1"
            if ! [[ "$JOBS" =~ ^[0-9]+$ ]]; then
                log_error "--jobs requires a numeric argument"
                exit 1
            fi
            ;;
        -h|--help)
            printf "${BOLD}MCons Universal Build System${NC}\n"
            printf "Usage: %s [OPTIONS]\n\n" "$0"
            printf "Options:\n"
            printf "  --clean        Deep-clean all caches and build artifacts\n"
            printf "  --debug        Build debug binaries (default: release)\n"
            printf "  --cli-only     Build only CLI binary\n"
            printf "  --app-only     Build only desktop app\n"
            printf "  --no-universal macOS: native arch only (skip x86_64)\n"
            printf "  --no-dmg       macOS: skip DMG creation\n"
            printf "  --no-nsis      Windows: skip NSIS portable packaging\n"
            printf "  --no-zip       Skip ZIP archive creation\n"
            printf "  --jobs N       Parallel jobs (default: nproc)\n"
            printf "  --verbose      Full compiler output\n"
            printf "  --dry-run      Show plan without building\n"
            printf "  -h, --help     This help\n"
            exit 0
            ;;
        *)
            log_warn "Unknown flag: $1 (ignored)"
            ;;
    esac
    shift
done

# ── Detect host OS ───────────────────────────────────────────────────────────
OS_RAW="$(uname -s)"
case "$OS_RAW" in
    Darwin)                     HOST_OS="macos" ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) HOST_OS="windows" ;;
    Linux)                      HOST_OS="linux" ;;
    *)                          HOST_OS="unknown" ;;
esac

# ── CPU count ────────────────────────────────────────────────────────────────
if [[ -z "$JOBS" ]]; then
    case "$HOST_OS" in
        macos)   JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4) ;;
        windows) JOBS=${NUMBER_OF_PROCESSORS:-4} ;;
        linux)   JOBS=$(nproc 2>/dev/null || echo 4) ;;
        *)       JOBS=4 ;;
    esac
fi

# ── Cargo env for speed ─────────────────────────────────────────────────────
export CARGO_BUILD_JOBS="$JOBS"
# Use mold/lld linker if available for dramatically faster linking
if [[ "$HOST_OS" == "linux" ]] && command -v mold &>/dev/null; then
    export RUSTFLAGS="${RUSTFLAGS:-} -C linker=clang -C link-arg=-fuse-ld=mold"
elif [[ "$HOST_OS" == "windows" ]]; then
    export RUSTFLAGS="${RUSTFLAGS:-} -C linker=lld-link"
elif [[ "$HOST_OS" == "macos" ]]; then
    # Apple's ld is fast enough; use zld if installed
    if command -v zld &>/dev/null; then
        export RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-fuse-ld=$(which zld)"
    fi
fi

# ── Version from Cargo.toml ─────────────────────────────────────────────────
VERSION=$(grep '^version' rust/Cargo.toml | head -1 | sed 's/.*= *"\(.*\)"/\1/')

# ── Cargo command wrapper ───────────────────────────────────────────────────
CARGO_MANIFEST="rust/Cargo.toml"
cargo_build() {
    local cmd=(cargo build)
    [[ -n "$CARGO_PROFILE_FLAG" ]] && cmd+=($CARGO_PROFILE_FLAG)
    cmd+=(--manifest-path "$CARGO_MANIFEST")
    cmd+=("$@")
    if [[ "$VERBOSE" == true ]]; then
        cmd+=(--verbose)
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_dim "Would run: ${cmd[*]}"
        return 0
    fi
    "${cmd[@]}"
}

# ── Prerequisite check helper ───────────────────────────────────────────────
require_cmd() {
    local cmd="$1"
    local install_hint="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "'$cmd' not found."
        [[ -n "$install_hint" ]] && log_dim "Install: $install_hint"
        return 1
    fi
    return 0
}

# ── File size helper ─────────────────────────────────────────────────────────
file_size() {
    local f="$1"
    if [[ "$HOST_OS" == "macos" ]]; then
        stat -f%z "$f" 2>/dev/null | awk '{
            if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824
            else if ($1 >= 1048576) printf "%.1f MB", $1/1048576
            else if ($1 >= 1024) printf "%.1f KB", $1/1024
            else printf "%d B", $1
        }'
    else
        stat --printf="%s" "$f" 2>/dev/null | awk '{
            if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824
            else if ($1 >= 1048576) printf "%.1f MB", $1/1048576
            else if ($1 >= 1024) printf "%.1f KB", $1/1024
            else printf "%d B", $1
        }'
    fi
}

# ── Print summary artifact ──────────────────────────────────────────────────
artifact_line() {
    local label="$1" path="$2"
    if [[ -e "$path" ]]; then
        printf "  ${GREEN}✓${NC} %-28s %s ${DIM}(%s)${NC}\n" "$label" "$path" "$(file_size "$path")"
    else
        printf "  ${RED}✗${NC} %-28s %s ${DIM}(missing)${NC}\n" "$label" "$path"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  HEADER
# ══════════════════════════════════════════════════════════════════════════════
printf "\n${BOLD}${CYAN}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║           MCons Build System  v%-22s║\n" "$VERSION"
printf "  ╚══════════════════════════════════════════════════════╝${NC}\n\n"

log_info "Host: ${BOLD}$HOST_OS${NC} ($OS_RAW) | Mode: ${BOLD}$BUILD_MODE${NC} | Target: ${BOLD}$TARGET_TYPE${NC} | Jobs: ${BOLD}$JOBS${NC}"
[[ "$DO_UNIVERSAL" == false ]] && log_info "Universal binary: disabled (native arch only)"
[[ "$DRY_RUN" == true ]] && log_warn "DRY RUN — no actual builds will execute"
echo

timer_start

# ══════════════════════════════════════════════════════════════════════════════
#  PREREQUISITES
# ══════════════════════════════════════════════════════════════════════════════
log_step "Checking prerequisites"

require_cmd cargo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
require_cmd rustup "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"

RUST_VER=$(rustc --version 2>/dev/null || echo "unknown")
CARGO_VER=$(cargo --version 2>/dev/null || echo "unknown")
log_ok "Rust toolchain: $RUST_VER"
log_dim "Cargo: $CARGO_VER"

# ══════════════════════════════════════════════════════════════════════════════
#  macOS BUILD
# ══════════════════════════════════════════════════════════════════════════════
build_macos() {
    local DIST_DIR="$ROOT_DIR/dist-macos"
    local BUILD_DIR="$ROOT_DIR/build"
    local RELEASE_DIR="$ROOT_DIR/release-macos"

    # ── Clean ────────────────────────────────────────────────────────────
    if [[ "$DO_CLEAN" == true ]]; then
        log_step "Cleaning macOS build artifacts"
        rm -rf "$DIST_DIR" "$BUILD_DIR" "$RELEASE_DIR" MCons.xcodeproj DerivedData
        cargo clean --manifest-path "$CARGO_MANIFEST" 2>/dev/null || true
        log_ok "Clean done"
    fi

    mkdir -p "$DIST_DIR" "$RELEASE_DIR"

    # ── CLI ──────────────────────────────────────────────────────────────
    if [[ "$TARGET_TYPE" == "all" || "$TARGET_TYPE" == "cli" ]]; then
        log_step "Building macOS CLI"

        if [[ "$DO_UNIVERSAL" == true ]]; then
            log_info "Universal binary: aarch64 + x86_64"
            # Ensure targets installed (fast no-op if already there)
            rustup target add aarch64-apple-darwin x86_64-apple-darwin 2>/dev/null || true

            # Build architectures sequentially to prevent host build artifact lock contention
            log_info "Compiling aarch64-apple-darwin..."
            cargo_build --bin mcons --target aarch64-apple-darwin

            log_info "Compiling x86_64-apple-darwin..."
            cargo_build --bin mcons --target x86_64-apple-darwin

            if [[ "$DRY_RUN" == false ]]; then
                lipo -create -output "$DIST_DIR/mcons" \
                    "rust/target/aarch64-apple-darwin/$BUILD_MODE/mcons" \
                    "rust/target/x86_64-apple-darwin/$BUILD_MODE/mcons"
            fi
        else
            log_info "Native arch only"
            cargo_build --bin mcons
            if [[ "$DRY_RUN" == false ]]; then
                cp "rust/target/$BUILD_MODE/mcons" "$DIST_DIR/mcons"
            fi
        fi

        if [[ "$DRY_RUN" == false ]]; then
            chmod +x "$DIST_DIR/mcons"
            strip "$DIST_DIR/mcons" 2>/dev/null || true
            cp "$DIST_DIR/mcons" "$RELEASE_DIR/"
            log_ok "CLI binary: $DIST_DIR/mcons ($(file_size "$DIST_DIR/mcons"))"
        fi
    fi

    # ── SwiftUI App ──────────────────────────────────────────────────────
    if [[ "$TARGET_TYPE" == "all" || "$TARGET_TYPE" == "app" ]]; then
        log_step "Building macOS SwiftUI App"

        # XcodeGen
        if ! require_cmd xcodegen "brew install xcodegen"; then
            log_error "Cannot build .app without xcodegen"
            exit 1
        fi

        log_info "Generating Xcode project..."
        if [[ "$DRY_RUN" == false ]]; then
            xcodegen generate --quiet 2>/dev/null || xcodegen generate
        fi

        local CONFIGURATION="Release"
        [[ "$BUILD_MODE" == "debug" ]] && CONFIGURATION="Debug"

        log_info "Building MCons.app ($CONFIGURATION)..."
        if [[ "$DRY_RUN" == false ]]; then
            xcodebuild -project MCons.xcodeproj \
                -scheme MCons \
                -configuration "$CONFIGURATION" \
                -derivedDataPath "$BUILD_DIR" \
                -jobs "$JOBS" \
                CODE_SIGN_IDENTITY="" \
                CODE_SIGNING_REQUIRED=NO \
                CODE_SIGNING_ALLOWED=NO \
                COMPILER_INDEX_STORE_ENABLE=NO \
                GCC_WARN_INHIBIT_ALL_WARNINGS=YES \
                SWIFT_VERSION=5 \
                SWIFT_STRICT_CONCURRENCY=minimal \
                ${VERBOSE:+-verbose} \
                2>&1 | {
                    if [[ "$VERBOSE" == true ]]; then
                        cat
                    else
                        # Show only warnings/errors and build phases
                        grep -E '(error:|warning:|BUILD |COMPILE |LINK |GENERATE |PhaseScriptExecution)' || true
                    fi
                }

            local APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/MCons.app"
            if [[ ! -d "$APP_PATH" ]]; then
                log_error "MCons.app not found at $APP_PATH"
                log_dim "Check xcodebuild output with --verbose"
                exit 1
            fi

            # Copy to dist
            rm -rf "$DIST_DIR/MCons.app"
            cp -R "$APP_PATH" "$DIST_DIR/"
            codesign --force --deep --sign - "$DIST_DIR/MCons.app" 2>/dev/null || true
            log_ok "MCons.app built"

            # ── ZIP ──────────────────────────────────────────────────────
            if [[ "$DO_ZIP" == true ]]; then
                log_info "Creating release ZIP..."
                ditto -c -k --sequesterRsrc --keepParent \
                    "$DIST_DIR/MCons.app" "$RELEASE_DIR/MCons-macOS-release.zip"
                log_ok "ZIP: $RELEASE_DIR/MCons-macOS-release.zip ($(file_size "$RELEASE_DIR/MCons-macOS-release.zip"))"
            fi

            # ── DMG ──────────────────────────────────────────────────────
            if [[ "$DO_DMG" == true ]]; then
                log_info "Creating DMG installer..."
                local STAGING
                STAGING=$(mktemp -d)
                cp -R "$DIST_DIR/MCons.app" "$STAGING/"
                ln -s /Applications "$STAGING/Applications"
                hdiutil create \
                    -volname "MCons" \
                    -srcfolder "$STAGING" \
                    -ov -format UDZO \
                    -imagekey zlib-level=9 \
                    "$RELEASE_DIR/MCons.dmg" \
                    >/dev/null 2>&1
                rm -rf "$STAGING"
                log_ok "DMG: $RELEASE_DIR/MCons.dmg ($(file_size "$RELEASE_DIR/MCons.dmg"))"
            fi
        fi
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  WINDOWS BUILD
# ══════════════════════════════════════════════════════════════════════════════
build_windows() {
    local RELEASE_DIR="$ROOT_DIR/release-windows"
    local STAGING_DIR="$ROOT_DIR/rust/staging"
    local OUTPUT_DIR="$ROOT_DIR/rust/output"
    local WIN_TARGET="x86_64-pc-windows-msvc"

    # ── Clean ────────────────────────────────────────────────────────────
    if [[ "$DO_CLEAN" == true ]]; then
        log_step "Cleaning Windows build artifacts"
        rm -rf "$RELEASE_DIR" "$STAGING_DIR" "$OUTPUT_DIR" "$ROOT_DIR/dist"
        cargo clean --manifest-path "$CARGO_MANIFEST" 2>/dev/null || true
        log_ok "Clean done"
    fi

    mkdir -p "$RELEASE_DIR" "$STAGING_DIR" "$OUTPUT_DIR" "$ROOT_DIR/dist"

    # ── Ensure MSVC target ───────────────────────────────────────────────
    rustup target add "$WIN_TARGET" 2>/dev/null || true

    # ── Locate VS Developer environment ──────────────────────────────────
    _init_msvc_env() {
        # Already in MSVC env?
        if command -v cl.exe &>/dev/null && command -v link.exe &>/dev/null; then
            return 0
        fi

        local VS_PATHS=(
            "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/Tools/Launch-VsDevShell.ps1"
            "C:/Program Files/Microsoft Visual Studio/2022/Community/Common7/Tools/Launch-VsDevShell.ps1"
            "C:/Program Files/Microsoft Visual Studio/2022/Professional/Common7/Tools/Launch-VsDevShell.ps1"
            "C:/Program Files/Microsoft Visual Studio/2022/Enterprise/Common7/Tools/Launch-VsDevShell.ps1"
        )
        for vs in "${VS_PATHS[@]}"; do
            if [[ -f "$vs" ]]; then
                log_info "Initializing VS Build Tools..."
                # shellcheck disable=SC2016
                eval "$(powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$vs' -Arch amd64 -HostArch amd64; Get-ChildItem env: | ForEach-Object { 'export ' + \$_.Name + '=\"' + \$_.Value + '\"' }" 2>/dev/null)" || true
                return 0
            fi
        done
        log_warn "VS Build Tools not found — relying on PATH"
    }

    _init_msvc_env

    # ── Build Rust workspace ─────────────────────────────────────────────
    log_step "Building Rust binaries (Windows x64)"

    if [[ "$TARGET_TYPE" == "all" || "$TARGET_TYPE" == "cli" ]]; then
        log_info "Building CLI (mcons.exe)..."
        cargo_build --bin mcons --target "$WIN_TARGET"
    fi
    if [[ "$TARGET_TYPE" == "all" || "$TARGET_TYPE" == "app" ]]; then
        log_info "Building App (mcons-app.exe)..."
        cargo_build --bin mcons-app --target "$WIN_TARGET"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dim "Dry run — skipping staging/packaging"
        return 0
    fi

    local BIN_DIR="rust/target/$WIN_TARGET/$BUILD_MODE"
    # Fallback to non-target-triple path
    [[ ! -d "$BIN_DIR" ]] && BIN_DIR="rust/target/$BUILD_MODE"

    # ── Stage binaries ───────────────────────────────────────────────────
    log_step "Staging artifacts"

    if [[ "$TARGET_TYPE" == "all" || "$TARGET_TYPE" == "app" ]]; then
        local APP_EXE="$BIN_DIR/mcons-app.exe"
        if [[ ! -f "$APP_EXE" ]]; then
            log_error "mcons-app.exe not found at $APP_EXE"
            exit 1
        fi
        cp "$APP_EXE" "$STAGING_DIR/"
        cp "$APP_EXE" "$RELEASE_DIR/"
        log_ok "mcons-app.exe staged"
    fi

    if [[ "$TARGET_TYPE" == "all" || "$TARGET_TYPE" == "cli" ]]; then
        local CLI_EXE="$BIN_DIR/mcons.exe"
        if [[ -f "$CLI_EXE" ]]; then
            cp "$CLI_EXE" "$STAGING_DIR/"
            cp "$CLI_EXE" "$RELEASE_DIR/"
            log_ok "mcons.exe staged"
        else
            log_warn "mcons.exe not found — CLI not built?"
        fi
    fi

    # Copy IconPacks into staging (force-overwrite to avoid "already exists")
    if [[ -d "MCons/Resources/IconPacks" ]]; then
        rm -rf "$STAGING_DIR/IconPacks"
        cp -r "MCons/Resources/IconPacks" "$STAGING_DIR/"
        log_ok "IconPacks staged"
    fi

    # ── NSIS Portable ────────────────────────────────────────────────────
    if [[ "$DO_NSIS" == true ]]; then
        log_step "NSIS Portable Packaging"

        local MAKENSIS=""
        if command -v makensis &>/dev/null; then
            MAKENSIS="makensis"
        elif [[ -f "C:/Program Files (x86)/NSIS/makensis.exe" ]]; then
            MAKENSIS="C:/Program Files (x86)/NSIS/makensis.exe"
        elif [[ -f "C:/Program Files/NSIS/makensis.exe" ]]; then
            MAKENSIS="C:/Program Files/NSIS/makensis.exe"
        fi

        if [[ -n "$MAKENSIS" ]]; then
            log_info "Building single-file portable MCons.exe..."
            if "$MAKENSIS" rust/nsis/portable.nsi; then
                if [[ -f "rust/output/MCons.exe" ]]; then
                    cp "rust/output/MCons.exe" "$RELEASE_DIR/MCons-Portable.exe"
                    cp "rust/output/MCons.exe" "$RELEASE_DIR/MCons.exe"
                    log_ok "Portable: $RELEASE_DIR/MCons-Portable.exe ($(file_size "$RELEASE_DIR/MCons-Portable.exe"))"
                fi
            else
                log_warn "NSIS build failed (non-fatal)"
            fi
        else
            log_warn "NSIS not found — skipping portable build"
            log_dim "Install: winget install NSIS.NSIS | choco install nsis | scoop install nsis"
        fi
    fi

    # ── ZIP ──────────────────────────────────────────────────────────────
    if [[ "$DO_ZIP" == true ]]; then
        log_step "Creating Windows ZIP archive"
        # Stage a clean dist/ folder for zipping
        local DIST_DIR="$ROOT_DIR/dist"
        rm -rf "$DIST_DIR"
        mkdir -p "$DIST_DIR"

        [[ -f "$STAGING_DIR/mcons-app.exe" ]] && cp "$STAGING_DIR/mcons-app.exe" "$DIST_DIR/"
        [[ -f "$STAGING_DIR/mcons.exe" ]]     && cp "$STAGING_DIR/mcons.exe" "$DIST_DIR/"
        [[ -d "$STAGING_DIR/IconPacks" ]]     && cp -r "$STAGING_DIR/IconPacks" "$DIST_DIR/"

        # PowerShell Compress-Archive (robust on Windows)
        if command -v powershell &>/dev/null; then
            powershell -NoProfile -Command "
                if (Test-Path '$RELEASE_DIR/MCons-windows-x64.zip') { Remove-Item '$RELEASE_DIR/MCons-windows-x64.zip' -Force }
                Compress-Archive -Path '$DIST_DIR/*' -DestinationPath '$RELEASE_DIR/MCons-windows-x64.zip' -Force
            " 2>/dev/null && {
                log_ok "ZIP: $RELEASE_DIR/MCons-windows-x64.zip ($(file_size "$RELEASE_DIR/MCons-windows-x64.zip"))"
            } || {
                # Fallback to zip CLI
                if command -v zip &>/dev/null; then
                    (cd "$DIST_DIR" && zip -r "$RELEASE_DIR/MCons-windows-x64.zip" .)
                    log_ok "ZIP (zip): $RELEASE_DIR/MCons-windows-x64.zip"
                else
                    log_warn "Could not create ZIP (no zip tool or PowerShell)"
                fi
            }
        elif command -v zip &>/dev/null; then
            (cd "$DIST_DIR" && zip -r "$RELEASE_DIR/MCons-windows-x64.zip" .)
            log_ok "ZIP: $RELEASE_DIR/MCons-windows-x64.zip"
        fi
    fi

    log_ok "Windows artifacts in: $RELEASE_DIR/"
}

# ══════════════════════════════════════════════════════════════════════════════
#  LINUX BUILD
# ══════════════════════════════════════════════════════════════════════════════
build_linux() {
    local DIST_DIR="$ROOT_DIR/dist-linux"

    if [[ "$DO_CLEAN" == true ]]; then
        rm -rf "$DIST_DIR"
        cargo clean --manifest-path "$CARGO_MANIFEST" 2>/dev/null || true
    fi

    mkdir -p "$DIST_DIR"

    log_step "Building Linux CLI"
    cargo_build --bin mcons

    if [[ "$DRY_RUN" == false ]]; then
        cp "rust/target/$BUILD_MODE/mcons" "$DIST_DIR/"
        strip "$DIST_DIR/mcons" 2>/dev/null || true
        chmod +x "$DIST_DIR/mcons"
        log_ok "Linux CLI: $DIST_DIR/mcons ($(file_size "$DIST_DIR/mcons"))"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  DISPATCH
# ══════════════════════════════════════════════════════════════════════════════
case "$HOST_OS" in
    macos)   build_macos ;;
    windows) build_windows ;;
    linux)   build_linux ;;
    *)
        log_error "Unsupported OS: $OS_RAW"
        exit 1
        ;;
esac

# ══════════════════════════════════════════════════════════════════════════════
#  SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
printf "\n${BOLD}${GREEN}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║           BUILD COMPLETE — %-26s║\n" "$(timer_elapsed)"
printf "  ╚══════════════════════════════════════════════════════╝${NC}\n\n"

# Show artifact listing
case "$HOST_OS" in
    macos)
        artifact_line "CLI (Universal)"    "dist-macos/mcons"
        artifact_line "MCons.app"          "dist-macos/MCons.app"
        artifact_line "Release ZIP"        "release-macos/MCons-macOS-release.zip"
        artifact_line "Release DMG"        "release-macos/MCons.dmg"
        artifact_line "CLI (release)"      "release-macos/mcons"
        ;;
    windows)
        artifact_line "mcons-app.exe"      "release-windows/mcons-app.exe"
        artifact_line "mcons.exe (CLI)"    "release-windows/mcons.exe"
        artifact_line "MCons-Portable.exe" "release-windows/MCons-Portable.exe"
        artifact_line "Windows ZIP"        "release-windows/MCons-windows-x64.zip"
        ;;
    linux)
        artifact_line "mcons (CLI)"        "dist-linux/mcons"
        ;;
esac

echo
