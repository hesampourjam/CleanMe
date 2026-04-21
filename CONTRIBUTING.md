# Contributing to CleanMe

Thanks for your interest. A few ground rules to keep things moving.

## Before you start

- **Open an issue first** for anything bigger than a typo or small bugfix. It's faster to discuss direction before you write code than after.
- Check [`CLAUDE.md`](CLAUDE.md) — it documents the architecture decisions and what's intentionally out of scope. "Why isn't this sandboxed?" and similar questions are answered there.

## Development setup

```bash
git clone https://github.com/hesampourjam/CleanMe.git
cd cleanme
./scripts/bootstrap.sh          # generates CleanMe.xcodeproj via XcodeGen
open CleanMe.xcodeproj
```

Requirements: macOS 13+, Xcode 15+, Homebrew (for the one-time XcodeGen install).

## Running tests

```bash
xcodebuild test -scheme CleanMe -destination 'platform=macOS'
```

Or `cmd+U` in Xcode.

## Code style

- Follow Apple's Swift API Design Guidelines.
- Keep view files small — if a view passes ~200 lines, extract subviews.
- All filesystem work goes in an `actor` in `Services/`. No `FileManager` calls from views.
- Never use `rm` or `FileManager.removeItem` for user-facing deletions. Always `NSWorkspace.shared.recycle`.

## Commits

- One logical change per commit. `git rebase -i` before you open the PR.
- Present-tense imperative messages: "Add orphan detector" not "Added orphan detector" or "Adding orphan detector".
- Reference the issue number if one exists: `Fix crash on apps with no Info.plist (#42)`.

## Pull requests

- Describe what changed and why.
- Include before/after screenshots for any UI change.
- Tests for new service-layer code. UI is exempt for now.

## Releasing (maintainers)

See [`docs/releasing.md`](docs/releasing.md).
