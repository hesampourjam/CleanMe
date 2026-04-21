# Xcode project setup

The project file is **generated** from [`project.yml`](../project.yml) using [XcodeGen](https://github.com/yonaskolb/XcodeGen). It's not checked in — run the bootstrap script once after cloning.

## First-time setup

```bash
./scripts/bootstrap.sh
open CleanMe.xcodeproj
```

The script installs XcodeGen via Homebrew if it's not already on your PATH, then generates `CleanMe.xcodeproj`.

Requirements: macOS 13+, Xcode 15+, Homebrew (for the initial XcodeGen install).

## When to regenerate

After any change to `project.yml` — or after adding/removing/moving source files, since XcodeGen picks them up by walking the `CleanMe/` and `CleanMeTests/` directories. Just rerun:

```bash
./scripts/bootstrap.sh
```

(or `xcodegen generate` if you already have it installed).

Any in-Xcode project edits you make directly will be **wiped** the next time you run this. Make structural changes in `project.yml`, not in Xcode's project navigator.

## What the project contains

- **CleanMe** (application target) — `macOS 13.0+`, hardened runtime on, sandbox off via `CleanMe.entitlements`. Bundle ID: `dev.cleanme.CleanMe`.
- **CleanMeTests** (unit-test bundle) — hosted by the app so `@testable import CleanMe` works.
- **CleanMe scheme** — runs the app on ⌘R, runs the test bundle on ⌘U.

## Running tests from CLI

```bash
xcodebuild test -project CleanMe.xcodeproj -scheme CleanMe -destination 'platform=macOS'
```

## Why the project isn't checked in

A `project.pbxproj` is fragile — Xcode silently rewrites it on open and the diff churn drowns real changes. XcodeGen gives us a declarative source of truth that's trivial to diff.
