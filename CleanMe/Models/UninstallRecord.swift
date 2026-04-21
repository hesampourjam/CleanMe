import Foundation

struct TrashedItem: Codable, Hashable, Sendable {
    let originalURL: URL
    let trashedURL: URL?
    let sizeBytes: Int64
}

struct UninstallRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let appName: String
    let bundleID: String
    let appVersion: String?
    let uninstalledAt: Date
    let items: [TrashedItem]
    let skippedAdminItems: [URL]

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    init(
        id: UUID = UUID(),
        appName: String,
        bundleID: String,
        appVersion: String?,
        uninstalledAt: Date = Date(),
        items: [TrashedItem],
        skippedAdminItems: [URL] = []
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.appVersion = appVersion
        self.uninstalledAt = uninstalledAt
        self.items = items
        self.skippedAdminItems = skippedAdminItems
    }
}
