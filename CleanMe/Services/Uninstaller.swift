import AppKit
import Foundation

enum UninstallError: LocalizedError {
    case systemProtected(appName: String)
    case nothingToRemove

    var errorDescription: String? {
        switch self {
        case .systemProtected(let name): return "\(name) is a system app and cannot be removed."
        case .nothingToRemove: return "Nothing selected to remove."
        }
    }
}

struct UninstallResult: Sendable {
    let record: UninstallRecord
    let failures: [URL]
}

final class Uninstaller {
    private let workspace: NSWorkspace
    private let fm: FileManager

    init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fm = fileManager
    }

    /// Terminates running instances of the app (if any), then moves the bundle and every
    /// selected leftover to the Trash. Admin-required items are collected separately and skipped.
    func uninstall(
        app: InstalledApp,
        leftovers: [AssociatedFile]
    ) async throws -> UninstallResult {
        if app.isSystemProtected {
            throw UninstallError.systemProtected(appName: app.name)
        }

        await terminate(bundleID: app.bundleID)

        var urls: [URL] = [app.url]
        var skippedAdmin: [URL] = []
        for file in leftovers {
            if file.requiresAdmin {
                skippedAdmin.append(file.url)
            } else {
                urls.append(file.url)
            }
        }

        // Size snapshot before trashing — once recycled, the item may no longer be enumerable.
        let sizeByURL: [URL: Int64] = Dictionary(uniqueKeysWithValues: leftovers.map { ($0.url, $0.sizeBytes) })
        let appSize = app.sizeBytes ?? 0

        let (trashed, failures) = await recycle(urls: urls)

        let items: [TrashedItem] = urls.map { url in
            TrashedItem(
                originalURL: url,
                trashedURL: trashed[url],
                sizeBytes: url == app.url ? appSize : (sizeByURL[url] ?? 0)
            )
        }

        let record = UninstallRecord(
            appName: app.name,
            bundleID: app.bundleID,
            appVersion: app.version,
            items: items,
            skippedAdminItems: skippedAdmin
        )
        return UninstallResult(record: record, failures: failures)
    }

    // MARK: - Terminate

    private func terminate(bundleID: String) async {
        guard !bundleID.isEmpty else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return }

        for app in running { _ = app.terminate() }

        // 1-second grace period, then force-terminate stragglers.
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        for app in running where !app.isTerminated {
            _ = app.forceTerminate()
        }
    }

    // MARK: - Recycle

    /// Returns (originalURL -> trashedURL) for successes, and a list of failures.
    private func recycle(urls: [URL]) async -> ([URL: URL], [URL]) {
        await withCheckedContinuation { continuation in
            workspace.recycle(urls) { newURLs, error in
                var mapping: [URL: URL] = [:]
                for (original, new) in newURLs {
                    mapping[original] = new
                }
                let failures = urls.filter { mapping[$0] == nil }
                if error != nil {
                    continuation.resume(returning: (mapping, failures))
                } else {
                    continuation.resume(returning: (mapping, failures))
                }
            }
        }
    }
}
