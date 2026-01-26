#!/bin/bash
set -e

echo "=== Vox Pre-Release Smoke Test ==="
echo ""
echo "Manual checklist (run on a CLEAN machine or user account):"
echo ""
echo "[ ] 1. App launches without crashing"
echo "[ ] 2. Hotkey (Option+Space) triggers recording HUD"
echo "[ ] 3. Recording produces audio (check with --verbose)"
echo "[ ] 4. Sign-in button opens browser"
echo "[ ] 5. After web auth, app receives token (check logs)"
echo "[ ] 6. Dictation works end-to-end after sign-in"
echo ""
echo "Running automated checks..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/verify-plist.sh"
