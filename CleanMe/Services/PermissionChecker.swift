import AppKit
import Combine
import Foundation

/// Probes Full Disk Access by attempting to read a known FDA-gated path.
/// No way to query FDA status programmatically — reading is the only reliable probe.
@MainActor
final class PermissionChecker: ObservableObject {
    @Published private(set) var hasFullDiskAccess: Bool = false
    private let fm: FileManager

    init(fileManager: FileManager = .default) {
        self.fm = fileManager
        refresh()
    }

    func refresh() {
        hasFullDiskAccess = Self.probeFullDiskAccess(fileManager: fm)
    }

    /// Try to read Safari's bookmarks plist; fall back to listing ~/Library/Mail.
    /// Both are FDA-gated. If either succeeds we consider FDA granted.
    static func probeFullDiskAccess(fileManager: FileManager = .default) -> Bool {
        let home = fileManager.homeDirectoryForCurrentUser
        let safariBookmarks = home.appendingPathComponent("Library/Safari/Bookmarks.plist")
        if (try? Data(contentsOf: safariBookmarks, options: .mappedIfSafe)) != nil {
            return true
        }
        let mail = home.appendingPathComponent("Library/Mail")
        if let contents = try? fileManager.contentsOfDirectory(atPath: mail.path), !contents.isEmpty {
            return true
        }
        return false
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
