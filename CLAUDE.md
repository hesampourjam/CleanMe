# CleanMe — Claude Code spec

This file is the single source of truth for building CleanMe. Claude Code reads it at session start (it's named `CLAUDE.md` on purpose). Keep it current as decisions change.

## What we're building

A native macOS app that uninstalls other apps and their leftover files. Think FreeMacSoft's AppCleaner or Nektony's App Cleaner & Uninstaller — but free and SwiftUI-native.

Target: macOS 13+ (Ventura). No Mac App Store — distributed as a DMG via GitHub Releases.

## Stack

- **Swift 5.9+ / SwiftUI** — no Catalyst, no AppKit-only, no Electron
- **No external dependencies** at runtime. Everything is stdlib + Apple frameworks.
- **Xcode project** checked into the repo (`CleanMe.xcodeproj`). No Swift Package Manager for the app itself (use SPM only if a feature genuinely needs a library).
- **Not sandboxed.** `com.apple.security.app-sandbox` = NO. A sandboxed build cannot enumerate `~/Library`, which defeats the whole point.
- **Hardened runtime** ON. Required for notarization, and for Gatekeeper to let users open unsigned builds with right-click → Open.

## Architecture

MVVM with actors for all filesystem work so the UI never blocks.

```
CleanMe/
├── CleanMeApp.swift                 @main, WindowGroup
├── Models/
│   ├── InstalledApp.swift
│   ├── AssociatedFile.swift
│   └── UninstallRecord.swift
├── Services/
│   ├── AppScanner.swift             actor, enumerates .app bundles
│   ├── LeftoverFinder.swift         actor, matches bundle IDs against Library dirs
│   ├── Uninstaller.swift             NSWorkspace.recycle() + terminate + privileged helper
│   ├── OrphanDetector.swift         actor, finds leftovers with no parent app
│   ├── StartupItemsService.swift    SMAppService wrapper for login items
│   ├── PermissionChecker.swift      probes Full Disk Access
│   └── HistoryStore.swift           persists UninstallRecord to disk (JSON in App Support)
├── Views/
│   ├── RootView.swift               NavigationSplitView shell
│   ├── AppListView.swift            sidebar app list
│   ├── AppDetailView.swift          main pane with leftover tree
│   ├── OrphansView.swift
│   ├── ExtensionsView.swift
│   ├── HistoryView.swift
│   ├── AboutView.swift              donate links live here
│   ├── Onboarding/
│   │   └── FDARequiredView.swift
│   └── Dialogs/
│       └── ConfirmUninstallSheet.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

### Key services

**`AppScanner`** — `actor`. Scans `/Applications`, `/Applications/Utilities`, and `~/Applications`. Each `.app` bundle produces an `InstalledApp` with name, bundle ID, version, URL, and size. Size computation uses `FileManager.enumerator` with `.totalFileAllocatedSizeKey` and is lazy (computed only when the app is selected, not during the initial scan).

**`LeftoverFinder`** — `actor`. Given an `InstalledApp`, searches a known set of `(URL, Kind, MatchMode)` tuples covering `~/Library/Preferences`, `~/Library/Caches`, `~/Library/Application Support`, `~/Library/Containers`, `~/Library/Group Containers`, `~/Library/LaunchAgents`, `~/Library/Logs`, `~/Library/Saved Application State`, `~/Library/HTTPStorages`, `~/Library/WebKit`, and the `/Library` counterparts. Three match modes:

- `bundleIDExact` — filename stem equals bundle ID (for Containers)
- `bundleIDPrefix` — filename stem equals bundle ID or starts with `bundleID.` (for Preferences, plists, etc.)
- `loose` — filename contains bundle ID OR equals app name if name is >3 chars (fallback; produces false positives, use sparingly)

Matching by bundle ID is the primary signal. App-name matching is fallback only.

**`Uninstaller`** — moves everything to Trash via `NSWorkspace.shared.recycle(_:completionHandler:)`. Never uses `rm` or `FileManager.removeItem`. Before moving, terminates any running instance of the target app via `NSRunningApplication.terminate()`, falling back to `forceTerminate()` after a 1-second grace period. Returns an `UninstallRecord` that includes original URLs and the trashed URLs (so restore is possible). System-protected apps (path starts with `/System/`, or bundle ID starts with `com.apple.`) are refused with a user-facing error.

**`StartupItemsService`** — wraps `SMAppService` (macOS 13+) to list, enable, and disable login items and launch agents for the current user. Daemon-level items in `/Library/LaunchDaemons` require a privileged helper (see below); for v1, surface them read-only with a "needs admin" badge.

**`PermissionChecker`** — probes Full Disk Access by attempting to read `~/Library/Safari/Bookmarks.plist` or `~/Library/Mail`. If it throws, FDA is not granted. Expose a published `@Observable` flag that gates the UI.

### Privileged operations (v2)

For removing items in `/Library/LaunchDaemons`, `/Library`, or other root-owned locations, we'll eventually need a privileged helper tool installed via `SMJobBless` (or the newer `SMAppService.daemon` on macOS 13+). Out of scope for v1 — just flag these items as "admin required" and skip them in the Trash operation, with a clear message.

## UI screens

All screens use the design already mocked up — flat, macOS-native, `NavigationSplitView` for sidebar-driven navigation.

| Screen | View file | Purpose |
|---|---|---|
| Main (apps) | `AppListView` + `AppDetailView` | Browse installed apps, preview leftovers, uninstall |
| Orphaned files | `OrphansView` | Leftovers from already-gone apps |
| Extensions & startup | `ExtensionsView` | Login items, launch agents, launch daemons |
| History | `HistoryView` | Past uninstalls, with "restore from Trash" |
| About | `AboutView` | Version, license, donate links, repo link |
| FDA onboarding | `FDARequiredView` | First-run permission request |
| Confirm uninstall | `ConfirmUninstallSheet` | Shown as `.sheet`, lists everything about to be trashed |

The sidebar has five top-level items: **Applications**, **Orphaned files**, **Extensions**, **History**, **About**. Applications is the default selection.

### About page — specifics

- App icon, name, version ("Version X.Y.Z · Build N"), line "Free & open source · macOS 13+"
- "Support development" section with two buttons in a 2-column grid:
  - **Buy me a coffee** — yellow `#FFDD00` background, links to `https://buymeacoffee.com/<handle>`
  - **GitHub Sponsors** — light pink background, heart icon, links to `https://github.com/sponsors/<handle>`
- List of links below: GitHub repo, Report issue, Privacy policy, Acknowledgements
- Footer: "Made with care in Vancouver, BC · © 2026"
- Links open via `NSWorkspace.shared.open(url)`

## Testing

- **Unit tests** for `LeftoverFinder` match logic. Fixture: a temp directory with known files matching/not-matching a fake bundle ID. Every match mode gets its own test.
- **Unit tests** for `AppScanner` folder-size computation with a known-size temp tree.
- **Integration test** for `Uninstaller` using a throwaway `.app` bundle in a temp dir (never touches real `/Applications`).
- No UI tests in v1. Too brittle for the ROI.

Run with `cmd+U` in Xcode or `xcodebuild test -scheme CleanMe -destination 'platform=macOS'`.

## Releases

A single GitHub Actions workflow handles builds on `v*` tag push: `.github/workflows/release.yml`. It builds, creates a DMG with `create-dmg`, optionally signs and notarizes if the right secrets are set, and attaches the DMG to a GitHub Release.

**Required secrets (optional — unsigned builds work without them):**

- `MACOS_CERTIFICATE` — base64 of Developer ID Application `.p12`
- `MACOS_CERTIFICATE_PWD` — password for the `.p12`
- `MACOS_CERTIFICATE_NAME` — common name of the cert (e.g. `Developer ID Application: Your Name (TEAMID)`)
- `NOTARIZATION_APPLE_ID` — Apple ID email
- `NOTARIZATION_TEAM_ID` — Apple Developer team ID
- `NOTARIZATION_PWD` — app-specific password from appleid.apple.com

If these are missing, the workflow produces an **unsigned DMG**. Users open it with right-click → Open, accept Gatekeeper once, done.

To cut a release:

```bash
git tag v1.0.0
git push --tags
```

## Decisions already made (don't revisit without a reason)

- SwiftUI, not AppKit. `NavigationSplitView`, not three-column split.
- Not sandboxed. Not Mac App Store.
- `NSWorkspace.recycle`, not `FileManager.removeItem`. Reversibility matters.
- Match by bundle ID first, name second. No fuzzy matching.
- No iCloud sync of history. Local JSON in `~/Library/Application Support/CleanMe/`.
- No telemetry, ever. This is a privacy tool; don't phone home.

## Open questions

- Do we want a "deep scan" mode that looks inside `Containers/*/Data/Library` recursively? Tradeoff: slower, more accurate.
- Does the privileged helper go in v2 or never?
- Sparkle for auto-updates, or just rely on GitHub Releases + a "check for updates" button that opens the releases page?

## For Claude Code specifically

When starting work on this project:

1. Read this file first.
2. Read `README.md` for the user-facing pitch.
3. Check `docs/` for any additional specs.
4. The models and service signatures in the first-draft Swift code (in conversation history or `docs/initial-draft.md` if present) are a starting point, not a contract — feel free to refactor, but preserve the architecture choices above.
5. When adding a new screen, create the view file in `Views/`, wire it into `RootView`'s navigation, and update the screen table above.
6. Prefer small, reviewable commits. One logical change per commit.
