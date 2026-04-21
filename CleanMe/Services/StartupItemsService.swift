import Foundation
import ServiceManagement

/// Wraps `SMAppService` (macOS 13+) for login items / launch agents owned by the current user.
///
/// v1 surfaces three buckets:
/// - **Login items** — registered via `SMAppService.loginItem(identifier:)` by other apps.
///   We can only manage our own, so this is read-only in v1.
/// - **User launch agents** — plists in `~/Library/LaunchAgents`, enumerated on disk.
/// - **System launch agents / daemons** — `/Library/LaunchAgents` and `/Library/LaunchDaemons`,
///   read-only with an "admin required" badge.
actor StartupItemsService {
    enum Scope: String, Sendable {
        case userAgent       // ~/Library/LaunchAgents
        case systemAgent     // /Library/LaunchAgents
        case systemDaemon    // /Library/LaunchDaemons
    }

    struct LaunchPlist: Identifiable, Hashable, Sendable {
        var id: URL { url }
        let url: URL
        let label: String?
        let scope: Scope
        let requiresAdmin: Bool
    }

    private let fm: FileManager
    init(fileManager: FileManager = .default) { self.fm = fileManager }

    func enumerateLaunchPlists() -> [LaunchPlist] {
        let home = fm.homeDirectoryForCurrentUser
        let sources: [(URL, Scope, Bool)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), .userAgent, false),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .systemAgent, true),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .systemDaemon, true),
        ]

        var results: [LaunchPlist] = []
        for (dir, scope, admin) in sources {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for entry in entries where entry.pathExtension.lowercased() == "plist" {
                let label = Self.readLabel(from: entry)
                results.append(LaunchPlist(url: entry, label: label, scope: scope, requiresAdmin: admin))
            }
        }
        return results.sorted { ($0.label ?? $0.url.lastPathComponent) < ($1.label ?? $1.url.lastPathComponent) }
    }

    private static func readLabel(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["Label"] as? String
    }
}
