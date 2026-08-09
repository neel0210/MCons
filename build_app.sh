#!/bin/bash
# build_app.sh — Builds MCons - Icons for MacOS and packages it as a proper .app bundle
#
# Usage:
#   ./build_app.sh          Build and package the app
#   ./build_app.sh --stop   Stop any running instance (without rebuilding)
set -euo pipefail

APP_NAME="MCons"
BUNDLE_ID="com.neel0210.mcons"
EXECUTABLE_NAME="MCons"
VERSION="1.0.0"
BUILD_DIR=".build/release"
OUTPUT_DIR="output"
APP_DIR="${OUTPUT_DIR}/${APP_NAME}.app"

# --- Stop running instances ---
stop_running() {
    local pids
    pids=$(pgrep -f "${EXECUTABLE_NAME}" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "🛑 Stopping running instance(s) of ${APP_NAME}..."
        pkill -f "${EXECUTABLE_NAME}" 2>/dev/null || true
        sleep 0.5
        # Force kill if still alive
        pids=$(pgrep -f "${EXECUTABLE_NAME}" 2>/dev/null || true)
        if [ -n "$pids" ]; then
            echo "⚠️  Force killing remaining processes..."
            pkill -9 -f "${EXECUTABLE_NAME}" 2>/dev/null || true
        fi
        echo "✅ Stopped."
    else
        echo "ℹ️  No running instance found."
    fi
}

# Handle --stop flag (stop only, don't build)
if [[ "${1:-}" == "--stop" ]]; then
    stop_running
    exit 0
fi

# Always stop running instances before building
stop_running

echo "🔨 Building MCons in Release mode..."
swift build -c release 2>&1

echo "📦 Creating app bundle..."

# Clean previous build and output
rm -rf "build/" "${OUTPUT_DIR}/"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"

# Copy resources from the SPM bundle
RESOURCE_BUNDLE=$(find ${BUILD_DIR} -name "MCons_MCons.bundle" -type d 2>/dev/null | head -1)
if [ -n "$RESOURCE_BUNDLE" ]; then
    echo "📁 Copying resource bundle..."
    cp -R "$RESOURCE_BUNDLE" "${APP_DIR}/Contents/Resources/"
fi

# Copy IconPacks directly
if [ -d "MCons/Resources/IconPacks" ]; then
    echo "📁 Copying IconPacks..."
    cp -R "MCons/Resources/IconPacks" "${APP_DIR}/Contents/Resources/"
fi

# Copy AppIcon.icns if present
if [ -f "MCons/Resources/AppIcon.icns" ]; then
    echo "🎨 Copying AppIcon.icns..."
    cp "MCons/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

# Create Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << EOF
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
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Neel0210. All rights reserved.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

echo ""
echo "✅ App bundle created at: ${OUTPUT_DIR}/${APP_NAME}.app"
echo "📂 To run: open \"${OUTPUT_DIR}/${APP_NAME}.app\""
echo ""
echo "💡 Tip: To run in debug mode instead, use:"
echo "   swift build && .build/debug/${EXECUTABLE_NAME}"
