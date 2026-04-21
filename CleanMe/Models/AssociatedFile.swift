import Foundation

enum AssociatedFileKind: String, Codable, Sendable, CaseIterable {
    case preferences
    case caches
    case applicationSupport
    case containers
    case groupContainers
    case launchAgents
    case launchDaemons
    case logs
    case savedState
    case httpStorages
    case webKit
    case appBundle
    case other

    var displayName: String {
        switch self {
        case .preferences: return "Preferences"
        case .caches: return "Caches"
        case .applicationSupport: return "Application Support"
        case .containers: return "Containers"
        case .groupContainers: return "Group Containers"
        case .launchAgents: return "Launch Agents"
        case .launchDaemons: return "Launch Daemons"
        case .logs: return "Logs"
        case .savedState: return "Saved State"
        case .httpStorages: return "HTTP Storages"
        case .webKit: return "WebKit"
        case .appBundle: return "App Bundle"
        case .other: return "Other"
        }
    }
}

enum MatchMode: Sendable {
    /// Filename stem equals bundle ID exactly (e.g. Containers).
    case bundleIDExact
    /// Filename stem equals bundle ID or starts with `bundleID.` (e.g. Preferences plists).
    case bundleIDPrefix
    /// Filename contains bundle ID, or equals the app name (names >3 chars). Fallback only.
    case loose
}

struct AssociatedFile: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let kind: AssociatedFileKind
    let sizeBytes: Int64
    /// True if removing this file requires admin privileges (e.g. /Library/LaunchDaemons).
    let requiresAdmin: Bool

    init(url: URL, kind: AssociatedFileKind, sizeBytes: Int64, requiresAdmin: Bool = false) {
        self.id = url
        self.url = url
        self.kind = kind
        self.sizeBytes = sizeBytes
        self.requiresAdmin = requiresAdmin
    }
}
