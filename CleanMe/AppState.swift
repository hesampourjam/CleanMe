import Combine
import Foundation

/// Top-level view state. Coordinates `AppScanner`, `LeftoverFinder`, `Uninstaller`, and `HistoryStore`
/// on behalf of the SwiftUI views, so actor hops stay out of the view layer.
@MainActor
final class AppState: ObservableObject {
    // Navigation
    enum NavItem: Hashable {
        case applications, orphans, extensions, history, about
    }
    @Published var selectedSection: NavItem = .applications

    // Apps
    @Published var apps: [InstalledApp] = []
    @Published var isScanning = false
    @Published var searchQuery: String = ""
    @Published var selectedAppID: InstalledApp.ID?

    // Selected app detail
    @Published var leftovers: [AssociatedFile] = []
    @Published var isLoadingLeftovers = false
    /// Set of leftover URLs the user has *unchecked* — default-on.
    @Published var deselectedLeftoverURLs: Set<URL> = []

    // Uninstall flow
    @Published var pendingUninstall: InstalledApp?
    @Published var lastError: String?

    // History
    @Published var history: [UninstallRecord] = []

    // Orphans / extensions
    @Published var orphans: [OrphanDetector.OrphanGroup] = []
    @Published var isLoadingOrphans = false
    @Published var launchPlists: [StartupItemsService.LaunchPlist] = []
    @Published var isLoadingLaunchPlists = false

    // Services
    private let scanner: AppScanner
    private let finder: LeftoverFinder
    private let uninstaller: Uninstaller
    private let historyStore: HistoryStore
    private let orphanDetector: OrphanDetector
    private let startupService: StartupItemsService

    init(
        scanner: AppScanner = AppScanner(),
        finder: LeftoverFinder = LeftoverFinder(),
        uninstaller: Uninstaller = Uninstaller(),
        historyStore: HistoryStore = HistoryStore(),
        orphanDetector: OrphanDetector = OrphanDetector(),
        startupService: StartupItemsService = StartupItemsService()
    ) {
        self.scanner = scanner
        self.finder = finder
        self.uninstaller = uninstaller
        self.historyStore = historyStore
        self.orphanDetector = orphanDetector
        self.startupService = startupService
    }

    // MARK: - Derived

    var filteredApps: [InstalledApp] {
        guard !searchQuery.isEmpty else { return apps }
        let q = searchQuery.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
        }
    }

    var selectedApp: InstalledApp? {
        guard let id = selectedAppID else { return nil }
        return apps.first { $0.id == id }
    }

    var selectedLeftovers: [AssociatedFile] {
        leftovers.filter { !deselectedLeftoverURLs.contains($0.url) }
    }

    // MARK: - Lifecycle

    func initialScan() async {
        history = await historyStore.load()
        await rescan()
    }

    func rescan() async {
        isScanning = true
        defer { isScanning = false }
        apps = await scanner.scan()
        if let id = selectedAppID, apps.contains(where: { $0.id == id }) == false {
            selectedAppID = nil
            leftovers = []
        }
        if selectedAppID == nil {
            selectedAppID = apps.first?.id
        }
        if let app = selectedApp {
            await loadLeftovers(for: app)
        }
    }

    // MARK: - Selection

    func select(appID: InstalledApp.ID?) async {
        selectedAppID = appID
        leftovers = []
        deselectedLeftoverURLs = []
        guard let app = selectedApp else { return }
        await loadLeftovers(for: app)
    }

    func loadLeftovers(for app: InstalledApp) async {
        isLoadingLeftovers = true
        defer { isLoadingLeftovers = false }

        async let sizeTask = scanner.folderSize(of: app.url)
        async let found = finder.find(for: app)

        let (size, files) = await (sizeTask, found)
        if let idx = apps.firstIndex(where: { $0.id == app.id }) {
            apps[idx].sizeBytes = size
        }
        guard selectedAppID == app.id else { return }
        leftovers = files
    }

    // MARK: - Uninstall

    func beginUninstall(app: InstalledApp) {
        pendingUninstall = app
    }

    func cancelUninstall() {
        pendingUninstall = nil
    }

    func confirmUninstall() async {
        guard let app = pendingUninstall else { return }
        pendingUninstall = nil
        let toRemove = selectedLeftovers
        do {
            let result = try await uninstaller.uninstall(app: app, leftovers: toRemove)
            try await historyStore.append(result.record)
            history = await historyStore.load()
            if !result.failures.isEmpty {
                lastError = "Some items could not be moved to Trash: \(result.failures.map(\.lastPathComponent).joined(separator: ", "))"
            }
            if let idx = apps.firstIndex(where: { $0.id == app.id }) {
                apps.remove(at: idx)
                selectedAppID = apps.indices.contains(idx) ? apps[idx].id : apps.last?.id
            }
            leftovers = []
            deselectedLeftoverURLs = []
            if let next = selectedApp {
                await loadLeftovers(for: next)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Leftover selection toggles

    func toggle(_ file: AssociatedFile) {
        if deselectedLeftoverURLs.contains(file.url) {
            deselectedLeftoverURLs.remove(file.url)
        } else {
            deselectedLeftoverURLs.insert(file.url)
        }
    }

    func setAllLeftovers(selected: Bool) {
        if selected {
            deselectedLeftoverURLs = []
        } else {
            deselectedLeftoverURLs = Set(leftovers.filter { !$0.requiresAdmin }.map(\.url))
        }
    }

    // MARK: - Orphans

    func loadOrphans() async {
        isLoadingOrphans = true
        defer { isLoadingOrphans = false }
        let installed = Set(apps.map(\.bundleID).filter { !$0.isEmpty })
        orphans = await orphanDetector.findOrphans(installedBundleIDs: installed)
    }

    // MARK: - Launch plists

    func loadLaunchPlists() async {
        isLoadingLaunchPlists = true
        defer { isLoadingLaunchPlists = false }
        launchPlists = await startupService.enumerateLaunchPlists()
    }

    // MARK: - History

    func deleteHistory(id: UUID) async {
        try? await historyStore.remove(id: id)
        history = await historyStore.load()
    }

    func clearHistory() async {
        try? await historyStore.clear()
        history = []
    }
}
