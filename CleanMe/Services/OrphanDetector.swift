import Foundation

/// Finds leftover files whose owning app is no longer installed.
///
/// Strategy: enumerate the direct children of every `LeftoverFinder` search location,
/// extract the candidate bundle ID from each filename, and keep those that don't map to
/// any installed bundle ID. Preferences `.ByHost` subdirectory is handled separately.
actor OrphanDetector {
    struct OrphanGroup: Identifiable, Hashable, Sendable {
        let id: String          // the inferred bundle ID (or filename stem)
        let files: [AssociatedFile]
        var totalBytes: Int64 { files.reduce(0) { $0 + $1.sizeBytes } }
    }

    private let locations: [LeftoverFinder.SearchLocation]
    private let fm: FileManager

    init(
        locations: [LeftoverFinder.SearchLocation] = LeftoverFinder.defaultLocations(),
        fileManager: FileManager = .default
    ) {
        self.locations = locations
        self.fm = fileManager
    }

    func findOrphans(installedBundleIDs: Set<String>) -> [OrphanGroup] {
        let installed = Set(installedBundleIDs.map { $0.lowercased() })
        var groups: [String: [AssociatedFile]] = [:]

        for loc in locations {
            guard let entries = try? fm.contentsOfDirectory(
                at: loc.url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                guard let bid = Self.inferBundleID(fromFileName: entry.lastPathComponent) else { continue }
                guard !installed.contains(bid.lowercased()) else { continue }

                let size = Self.size(of: entry, fileManager: fm)
                let file = AssociatedFile(url: entry, kind: loc.kind, sizeBytes: size, requiresAdmin: loc.requiresAdmin)
                groups[bid, default: []].append(file)
            }
        }

        return groups.map { OrphanGroup(id: $0.key, files: $0.value) }
            .sorted { $0.totalBytes > $1.totalBytes }
    }

    /// Infer a bundle ID from a filename by stripping a trailing `.plist` and trimming known suffixes.
    /// Only returns a value if the filename looks like reverse-DNS (`at least two dots between letters`).
    static func inferBundleID(fromFileName name: String) -> String? {
        var stem = name
        let url = URL(fileURLWithPath: name)
        if url.pathExtension.lowercased() == "plist" {
            stem = url.deletingPathExtension().lastPathComponent
        }
        // Common non-bundle-ID files to skip.
        if stem.hasPrefix(".") { return nil }

        let components = stem.split(separator: ".")
        guard components.count >= 2 else { return nil }
        // First component should look like a TLD-ish identifier (2-10 chars, letters).
        let first = components[0]
        guard first.count >= 2, first.count <= 10, first.allSatisfy({ $0.isLetter }) else { return nil }
        return stem
    }

    private static func size(of url: URL, fileManager: FileManager) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey, .isRegularFileKey]
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }
        if values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        var total: Int64 = 0
        for case let f as URL in enumerator {
            guard let v = try? f.resourceValues(forKeys: Set(keys)),
                  v.isRegularFile == true,
                  let s = v.totalFileAllocatedSize else { continue }
            total += Int64(s)
        }
        return total
    }
}
