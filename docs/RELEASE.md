# Release Guide

Vox has two release paths:
1. **Landfall (Automated)** — Versioning, changelog, and GitHub releases via CI
2. **macOS Signing (Manual/CI)** — Signed + notarized app bundle distribution

---

## Landfall Automated Releases

Vox uses [Landfall](https://github.com/misty-step/landfall) — Misty Step's GitHub Action for automated versioning, changelog generation, and release notes.

### How It Works

1. **Conventional Commits:** Use `feat:`, `fix:`, `refactor:`, `docs:` prefixes in commit messages
2. **Automatic Versioning:** Landfall analyzes commits and determines semver bump (major/minor/patch)
3. **Changelog Generation:** Updates `CHANGELOG.md` with categorized entries
4. **GitHub Release:** Creates release with auto-generated notes

### Triggers

- **Automatic:** On every successful CI run on `master` branch (after PR merge)
- **Manual:** `workflow_dispatch` in GitHub Actions UI

### Workflow

- **File:** `.github/workflows/release.yml`
- **Action:** `misty-step/landfall@v1`
- **Required secrets:**
  - `GH_RELEASE_TOKEN` — GitHub token with release permissions
  - `MOONSHOT_API_KEY` — LLM API key for release note generation

---

## macOS Signed + Notarized Distribution

For distributing a Gatekeeper-compliant `Vox.app` that users can run without security warnings.

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
