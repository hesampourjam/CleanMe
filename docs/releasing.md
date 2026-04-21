# Releasing

## TL;DR

```bash
git tag v1.0.0
git push --tags
```

GitHub Actions builds, packages a DMG, optionally notarizes it, and attaches it to a Release.

## Without an Apple Developer account

The workflow produces an **unsigned DMG**. Users open it with right-click → Open the first time, accept the Gatekeeper dialog, and macOS remembers the decision.

Include this in the release notes (the workflow generates them, but you can edit after):

```
⚠️ This build is unsigned. To open it:
1. Download the .dmg and drag CleanMe to Applications.
2. In Applications, right-click CleanMe and choose Open.
3. Click "Open" in the Gatekeeper dialog. macOS won't ask again.
```

## With an Apple Developer account ($99/year)

Set these secrets in **Settings → Secrets and variables → Actions**:

| Secret | How to get it |
|---|---|
| `MACOS_CERTIFICATE` | Export Developer ID Application cert from Keychain as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PWD` | The password you set when exporting |
| `MACOS_CERTIFICATE_NAME` | Full cert CN, e.g. `Developer ID Application: Your Name (ABCDE12345)` |
| `NOTARIZATION_APPLE_ID` | Your Apple ID email |
| `NOTARIZATION_TEAM_ID` | 10-char team ID from [appleid.apple.com](https://appleid.apple.com) or Apple Developer |
| `NOTARIZATION_PWD` | App-specific password generated at [appleid.apple.com](https://appleid.apple.com) |

With all six set, the workflow will sign and notarize automatically. Users can then open the DMG with a double-click, no Gatekeeper detour.

## Version scheme

Semantic versioning — `MAJOR.MINOR.PATCH`.

- `MAJOR` — breaking changes to the data format (e.g., history JSON schema)
- `MINOR` — new features
- `PATCH` — bug fixes only

Tag with a `v` prefix: `v1.2.3`. The workflow extracts the version from the tag name.

## Pre-releases

Tags with a hyphen (e.g. `v1.0.0-beta.1`) are marked as pre-release on GitHub automatically.

## Checksum

Each release includes a `.sha256` file alongside the DMG. Users can verify with:

```bash
shasum -a 256 -c CleanMe-1.0.0.dmg.sha256
```
