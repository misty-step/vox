#!/bin/bash
set -euo pipefail

# Vox DMG Build Script
# Creates a macOS .app bundle and DMG from Swift Package Manager build

VERSION=$(grep 'appVersion' Sources/VoxApp/Version.swift | sed 's/.*"\(.*\)".*/\1/')
APP_NAME="Vox"
BUNDLE_ID="io.mistystep.vox"
BUILD_DIR=".build/apple/Products/Release"
APP_DIR="dist/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "Building Vox v${VERSION}..."

# Clean previous build
rm -rf dist
mkdir -p dist

# Build release binary (universal binary for Intel + Apple Silicon)
echo "Compiling Swift package..."
swift build -c release --arch arm64 --arch x86_64

# Create .app bundle structure
echo "Creating app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp ".build/apple/Products/Release/VoxApp" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>${BUNDLE_ID}</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>vox</string>
            </array>
        </dict>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Vox needs microphone access for voice dictation.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy icon if exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    # Update Info.plist with icon reference
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "Creating DMG..."

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "create-dmg not found. Installing via Homebrew..."
    brew install create-dmg
fi

# Remove existing DMG if present
rm -f "dist/$DMG_NAME"

# Create DMG
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 190 \
    --app-drop-link 450 190 \
    --hide-extension "$APP_NAME.app" \
    "dist/$DMG_NAME" \
    "$APP_DIR"

echo ""
echo "Build complete!"
echo "  App: $APP_DIR"
echo "  DMG: dist/$DMG_NAME"
echo ""
echo "To install: open dist/$DMG_NAME"
