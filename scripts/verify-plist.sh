#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLIST="$PROJECT_ROOT/dist/Vox.app/Contents/Info.plist"

if [ ! -f "$PLIST" ]; then
    echo "FAIL: Info.plist not found at $PLIST"
    echo "Run ./scripts/build-dmg.sh first"
    exit 1
fi

REQUIRED_KEYS=(
    "CFBundleURLTypes"
    "NSMicrophoneUsageDescription"
    "LSUIElement"
)

echo "Checking Info.plist at: $PLIST"
echo ""

FAILED=0
for key in "${REQUIRED_KEYS[@]}"; do
    if /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" &>/dev/null; then
        echo "OK: $key"
    else
        echo "MISSING: $key"
        FAILED=1
    fi
done

echo ""
if [ $FAILED -eq 0 ]; then
    echo "PASS: All required plist keys present"
    exit 0
else
    echo "FAIL: Some required keys missing"
    exit 1
fi
