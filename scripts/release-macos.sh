#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Vox"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS_DIR="$APP_BUNDLE/Contents"
APP_MACOS_DIR="$APP_CONTENTS_DIR/MacOS"
PLIST_TEMPLATE_PATH="$ROOT_DIR/scripts/release/Info.plist.template"
PLIST_OUTPUT_PATH="$APP_CONTENTS_DIR/Info.plist"
RELEASE_BINARY_PATH="$ROOT_DIR/.build/release/$APP_NAME"
ZIP_PATH="$DIST_DIR/$APP_NAME-macos.zip"

SKIP_NOTARIZE=0

usage() {
    cat <<EOF
Build, sign, and notarize Vox.app for direct macOS distribution.

Usage:
  ./scripts/release-macos.sh [--skip-notarize]

Options:
  --skip-notarize   Build + bundle + sign + zip only (no notarization/stapling)
  -h, --help        Show this help

Required env vars:
  VOX_SIGNING_IDENTITY      Developer ID Application identity for codesign
                            Use '-' for ad-hoc signing when --skip-notarize

Required for notarization:
  VOX_NOTARY_PROFILE        Keychain profile name for notarytool credentials

Optional env vars:
  VOX_BUNDLE_ID             Defaults to com.misty-step.vox
  VOX_APP_VERSION           Defaults to 0.1.0
  VOX_BUILD_NUMBER          Defaults to UTC timestamp (YYYYMMDDHHMMSS)
EOF
}

log() {
    printf '[release] %s\n' "$*"
}

die() {
    printf '[release] error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
}

escape_for_sed() {
    printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
        --skip-notarize)
            SKIP_NOTARIZE=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
        esac
    done
}

validate_environment() {
    [[ -n "${VOX_SIGNING_IDENTITY:-}" ]] || die "VOX_SIGNING_IDENTITY is required"
    [[ -f "$PLIST_TEMPLATE_PATH" ]] || die "missing plist template at $PLIST_TEMPLATE_PATH"

    if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
        [[ -n "${VOX_NOTARY_PROFILE:-}" ]] || die "VOX_NOTARY_PROFILE is required unless --skip-notarize is set"
        [[ "$VOX_SIGNING_IDENTITY" != "-" ]] || die "ad-hoc signing ('-') is not valid for notarization"
    fi
}

prepare_release_metadata() {
    export VOX_BUNDLE_ID="${VOX_BUNDLE_ID:-com.misty-step.vox}"
    export VOX_APP_VERSION="${VOX_APP_VERSION:-0.1.0}"
    export VOX_BUILD_NUMBER="${VOX_BUILD_NUMBER:-$(date -u +%Y%m%d%H%M%S)}"
}

render_plist() {
    local bundle_id version build_number

    bundle_id="$(escape_for_sed "$VOX_BUNDLE_ID")"
    version="$(escape_for_sed "$VOX_APP_VERSION")"
    build_number="$(escape_for_sed "$VOX_BUILD_NUMBER")"

    sed \
        -e "s/__VOX_BUNDLE_ID__/$bundle_id/g" \
        -e "s/__VOX_APP_VERSION__/$version/g" \
        -e "s/__VOX_BUILD_NUMBER__/$build_number/g" \
        "$PLIST_TEMPLATE_PATH" >"$PLIST_OUTPUT_PATH"

    if ! plutil -lint "$PLIST_OUTPUT_PATH" >/dev/null; then
        die "generated plist is invalid: $PLIST_OUTPUT_PATH"
    fi
}

build_binary() {
    log "building release binary"
    swift build -c release
    [[ -x "$RELEASE_BINARY_PATH" ]] || die "expected binary not found at $RELEASE_BINARY_PATH"
}

bundle_app() {
    log "creating app bundle at $APP_BUNDLE"
    rm -rf "$DIST_DIR"
    mkdir -p "$APP_MACOS_DIR"
    cp "$RELEASE_BINARY_PATH" "$APP_MACOS_DIR/$APP_NAME"
    chmod +x "$APP_MACOS_DIR/$APP_NAME"
    render_plist
}

codesign_app() {
    log "codesigning app bundle"
    if [[ "$VOX_SIGNING_IDENTITY" == "-" ]]; then
        codesign --force --sign "-" "$APP_BUNDLE"
    else
        codesign --force --timestamp --options runtime --sign "$VOX_SIGNING_IDENTITY" "$APP_BUNDLE"
    fi
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

zip_bundle() {
    log "creating notarization archive $ZIP_PATH"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
}

notarize_app() {
    if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
        log "skipping notarization and Gatekeeper checks (--skip-notarize)"
        return
    fi

    log "submitting archive to Apple notarization service"
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$VOX_NOTARY_PROFILE" --wait

    log "stapling notarization ticket"
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"

    log "verifying Gatekeeper assessment"
    spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
}

print_artifacts() {
    log "done"
    printf '  app: %s\n' "$APP_BUNDLE"
    printf '  zip: %s\n' "$ZIP_PATH"
}

main() {
    parse_args "$@"

    require_command swift
    require_command codesign
    require_command ditto
    require_command xcrun
    require_command plutil

    if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
        require_command spctl
    fi

    validate_environment
    prepare_release_metadata
    build_binary
    bundle_app
    codesign_app
    zip_bundle
    notarize_app
    print_artifacts
}

main "$@"
