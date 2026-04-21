# CleanMe

A fast, native macOS uninstaller that finds and removes leftover files — caches, preferences, launch agents, orphaned daemons — that regular drag-to-Trash leaves behind.

Built with SwiftUI. Free and open source.

<p align="center">
  <img src="docs/screenshot-main.png" width="720" alt="Main window">
</p>

## Features

- **Clean uninstall** — finds associated files across `~/Library` and `/Library` and moves them to Trash alongside the app bundle
- **Orphaned leftovers** — detects files from apps already uninstalled and offers to reclaim the space
- **Login items & launch agents** — review and toggle everything that runs at startup or in the background
- **Reversible** — uses `NSWorkspace.recycle()` so every action can be restored from the Trash
- **Local & private** — no network requests, no telemetry, no tracking
- **Native** — SwiftUI, `NavigationSplitView`, ~5 MB download

## Install

### Download the DMG (recommended)

Grab the latest `.dmg` from the [Releases page](../../releases/latest), open it, and drag `CleanMe.app` into `Applications`.

> The release is **not notarized** by default. On first launch, right-click the app and choose **Open**, then confirm the dialog. macOS will remember the choice. (Maintainers with an Apple Developer account: see [`docs/releasing.md`](docs/releasing.md) to enable notarization.)

### Homebrew

```bash
brew install --cask hesampourjam/tap/cleanme
```

### Build from source

```bash
git clone https://github.com/hesampourjam/CleanMe.git
cd cleanme
open CleanMe.xcodeproj
# ⌘R to build and run
```

Requires Xcode 15+ and macOS 13+.

## Permissions

On first launch, CleanMe asks for **Full Disk Access**. This is required to enumerate files inside `~/Library/Containers`, `~/Library/Application Support`, and other protected directories. Without it, the leftover-finder will only see a fraction of the files it should.

CleanMe makes no network requests. You can confirm this with Little Snitch or by inspecting the source.

## Project structure

```
CleanMe/
├── Models/           InstalledApp, AssociatedFile, etc.
├── Services/         AppScanner, LeftoverFinder, Uninstaller
├── Views/            SwiftUI views, one file per screen
├── Resources/        Assets, Info.plist
└── CleanMeApp.swift
```

See [`CLAUDE.md`](CLAUDE.md) for the full architecture spec — that file is also the context document for working on this project with [Claude Code](https://www.claude.com/product/claude-code).

## Support

If CleanMe saved you time or disk space, a small tip keeps it maintained:

- ☕ [Buy me a coffee](https://buymeacoffee.com/hepour)
- 💜 [GitHub Sponsors](https://github.com/sponsors/hesampourjam)

## Contributing

Issues and PRs welcome. For larger changes, please open an issue first to discuss the approach. See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](LICENSE).

## Acknowledgements

Inspired by [Pearcleaner](https://github.com/alienator88/Pearcleaner) and the classic [AppCleaner](https://freemacsoft.net/appcleaner/) by FreeMacSoft.
