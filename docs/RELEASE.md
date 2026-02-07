# Release Guide (macOS, Signed + Notarized)

This repository ships a release script that builds a distributable `Vox.app`, signs it, notarizes it, staples the ticket, and verifies Gatekeeper.

## Prerequisites

- Apple Developer Program membership
- Developer ID Application certificate installed in local keychain
- Xcode command line tools (`xcode-select --install`)

## 1. Create notarytool credentials profile

Run once on each machine used for release:

```bash
xcrun notarytool store-credentials vox-notary \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

## 2. Export required environment variables

```bash
export VOX_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export VOX_NOTARY_PROFILE="vox-notary"
```

Optional metadata overrides:

```bash
export VOX_BUNDLE_ID="com.misty-step.vox"
export VOX_APP_VERSION="0.1.0"
export VOX_BUILD_NUMBER="$(date -u +%Y%m%d%H%M%S)"
```

## 3. Build + sign + notarize

```bash
./scripts/release-macos.sh
```

Artifacts:

- `dist/Vox.app`
- `dist/Vox-macos.zip`

## Local smoke check (no notarization)

Useful before wiring credentials:

```bash
VOX_SIGNING_IDENTITY="-" ./scripts/release-macos.sh --skip-notarize
```

This validates build, app bundle creation, ad-hoc signing, and zip output only.

## CI Release Workflow

Use `.github/workflows/release.yml` (`workflow_dispatch`).

Required repository secrets:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_KEYCHAIN_PASSWORD`
- `MACOS_SIGNING_IDENTITY`
- `MACOS_NOTARY_APPLE_ID`
- `MACOS_NOTARY_APP_PASSWORD`
- `MACOS_TEAM_ID`

The workflow supports two modes:

- `skip_notarize: false` (default): full signed + notarized artifact
- `skip_notarize: true`: ad-hoc signed smoke artifact (no notarization)
