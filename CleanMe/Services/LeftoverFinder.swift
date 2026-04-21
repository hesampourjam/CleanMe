import Foundation

actor LeftoverFinder {
    struct SearchLocation: Sendable {
        let url: URL
        let kind: AssociatedFileKind
        let mode: MatchMode
        let requiresAdmin: Bool
    }

    private let locations: [SearchLocation]
    private let fm: FileManager

    init(locations: [SearchLocation] = LeftoverFinder.defaultLocations(), fileManager: FileManager = .default) {
        self.locations = locations
        self.fm = fileManager
    }

    // MARK: - Default locations

    static func defaultLocations(home: URL? = nil) -> [SearchLocation] {
        let home = home ?? FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let root = URL(fileURLWithPath: "/Library")

        func entry(_ path: URL, _ kind: AssociatedFileKind, _ mode: MatchMode, admin: Bool = false) -> SearchLocation {
            SearchLocation(url: path, kind: kind, mode: mode, requiresAdmin: admin)
        }

        return [
            // User library
            entry(lib.appendingPathComponent("Preferences"), .preferences, .bundleIDPrefix),
            entry(lib.appendingPathComponent("Preferences/ByHost"), .preferences, .bundleIDPrefix),
            entry(lib.appendingPathComponent("Caches"), .caches, .bundleIDPrefix),
            entry(lib.appendingPathComponent("Application Support"), .applicationSupport, .bundleIDPrefix),
            entry(lib.appendingPathComponent("Containers"), .containers, .bundleIDExact),
            entry(lib.appendingPathComponent("Group Containers"), .groupContainers, .loose),
            entry(lib.appendingPathComponent("LaunchAgents"), .launchAgents, .bundleIDPrefix),
            entry(lib.appendingPathComponent("Logs"), .logs, .bundleIDPrefix),
            entry(lib.appendingPathComponent("Saved Application State"), .savedState, .bundleIDPrefix),
            entry(lib.appendingPathComponent("HTTPStorages"), .httpStorages, .bundleIDPrefix),
            entry(lib.appendingPathComponent("WebKit"), .webKit, .bundleIDPrefix),
            entry(lib.appendingPathComponent("Cookies"), .other, .loose),
            // Root library (admin-protected in v1)
            entry(root.appendingPathComponent("Application Support"), .applicationSupport, .bundleIDPrefix, admin: true),
            entry(root.appendingPathComponent("Caches"), .caches, .bundleIDPrefix, admin: true),
            entry(root.appendingPathComponent("Logs"), .logs, .bundleIDPrefix, admin: true),
            entry(root.appendingPathComponent("LaunchAgents"), .launchAgents, .bundleIDPrefix, admin: true),
            entry(root.appendingPathComponent("LaunchDaemons"), .launchDaemons, .bundleIDPrefix, admin: true),
            entry(root.appendingPathComponent("Preferences"), .preferences, .bundleIDPrefix, admin: true),
        ]
    }

    // MARK: - Matching

    func find(for app: InstalledApp) -> [AssociatedFile] {
        var results: [AssociatedFile] = []
        var seen = Set<URL>()

        for location in locations {
            guard let entries = try? fm.contentsOfDirectory(
                at: location.url,
                includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                guard LeftoverFinder.nameMatches(
                    fileName: entry.lastPathComponent,
                    bundleID: app.bundleID,
                    appName: app.name,
                    mode: location.mode
                ) else { continue }

                let resolved = entry.resolvingSymlinksInPath()
                guard seen.insert(resolved).inserted else { continue }

                let size = size(of: entry)
                results.append(AssociatedFile(
                    url: entry,
                    kind: location.kind,
                    sizeBytes: size,
                    requiresAdmin: location.requiresAdmin
                ))
            }
        }

        return results.sorted { $0.url.path < $1.url.path }
    }

    /// Pure match predicate — exposed as `static` so tests can call it without building a directory tree.
    static func nameMatches(fileName: String, bundleID: String, appName: String, mode: MatchMode) -> Bool {
        // Treat `.plist` as the only extension worth stripping for matching.
        // Other files (.app, .log, directories) match on their full basename.
        let stem: String = {
            let url = URL(fileURLWithPath: fileName)
            if url.pathExtension.lowercased() == "plist" {
                return url.deletingPathExtension().lastPathComponent
            }
            return fileName
        }()

        let bid = bundleID.lowercased()
        let name = appName.lowercased()
        let lowerStem = stem.lowercased()
        let lowerFull = fileName.lowercased()

        switch mode {
        case .bundleIDExact:
            guard !bid.isEmpty else { return false }
            return lowerStem == bid

        case .bundleIDPrefix:
            guard !bid.isEmpty else { return false }
            if lowerStem == bid { return true }
            return lowerStem.hasPrefix(bid + ".")

        case .loose:
            if !bid.isEmpty, lowerFull.contains(bid) { return true }
            // App name only if long enough to reduce false positives.
            guard name.count > 3 else { return false }
            return lowerStem == name || lowerStem.hasPrefix(name + ".")
        }
    }

    private func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey, .isRegularFileKey]
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }

        if values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }

        // Directory — sum recursively.
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let v = try? fileURL.resourceValues(forKeys: Set(keys)),
                  v.isRegularFile == true,
                  let s = v.totalFileAllocatedSize else { continue }
            total += Int64(s)
        }
        return total
    }
}
