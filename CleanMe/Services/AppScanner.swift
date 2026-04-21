import Foundation

actor AppScanner {
    /// Locations scanned for installed .app bundles.
    static let defaultSearchPaths: [URL] = {
        let fm = FileManager.default
        var urls: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
        ]
        if let home = fm.urls(for: .applicationDirectory, in: .userDomainMask).first {
            urls.append(home)
        }
        return urls
    }()

    private let searchPaths: [URL]
    private let fm: FileManager

    init(searchPaths: [URL] = AppScanner.defaultSearchPaths, fileManager: FileManager = .default) {
        self.searchPaths = searchPaths
        self.fm = fileManager
    }

    /// Enumerate .app bundles at the top level of each search path.
    /// Size is left nil; callers compute it lazily via `folderSize(of:)`.
    func scan() -> [InstalledApp] {
        var seen = Set<URL>()
        var apps: [InstalledApp] = []

        for root in searchPaths {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in entries where url.pathExtension == "app" {
                let resolved = url.resolvingSymlinksInPath()
                guard seen.insert(resolved).inserted else { continue }
                if let app = readBundle(at: url) {
                    apps.append(app)
                }
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func readBundle(at url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary ?? [:]

        let bundleID = bundle.bundleIdentifier ?? ""
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let version = (info["CFBundleShortVersionString"] as? String)
            ?? (info["CFBundleVersion"] as? String)

        return InstalledApp(name: name, bundleID: bundleID, version: version, url: url)
    }

    /// Recursive folder size in bytes using file allocated size (disk usage, not logical size).
    /// Returns 0 on error rather than throwing — callers treat a missing size as unknown.
    func folderSize(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize else { continue }
            total += Int64(size)
        }
        return total
    }
}
