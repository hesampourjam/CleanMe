import Foundation

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleID: String
    let version: String?
    let url: URL
    var sizeBytes: Int64?

    init(name: String, bundleID: String, version: String?, url: URL, sizeBytes: Int64? = nil) {
        self.id = bundleID.isEmpty ? url.path : bundleID
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.url = url
        self.sizeBytes = sizeBytes
    }

    var isSystemProtected: Bool {
        url.path.hasPrefix("/System/") || bundleID.hasPrefix("com.apple.")
    }
}
