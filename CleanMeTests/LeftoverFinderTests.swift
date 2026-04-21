import XCTest
@testable import CleanMe

final class LeftoverFinderMatchTests: XCTestCase {
    // MARK: - bundleIDExact

    func test_bundleIDExact_matchesExactStem() {
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "com.acme.Widget",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .bundleIDExact
        ))
    }

    func test_bundleIDExact_isCaseInsensitive() {
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "COM.ACME.Widget",
            bundleID: "com.acme.widget",
            appName: "Widget",
            mode: .bundleIDExact
        ))
    }

    func test_bundleIDExact_rejectsPrefixedStem() {
        XCTAssertFalse(LeftoverFinder.nameMatches(
            fileName: "com.acme.Widget.plugin",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .bundleIDExact
        ))
    }

    func test_bundleIDExact_rejectsAppNameOnly() {
        XCTAssertFalse(LeftoverFinder.nameMatches(
            fileName: "Widget",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .bundleIDExact
        ))
    }

    func test_bundleIDExact_emptyBundleID_neverMatches() {
        XCTAssertFalse(LeftoverFinder.nameMatches(
            fileName: "Widget",
            bundleID: "",
            appName: "Widget",
            mode: .bundleIDExact
        ))
    }

    // MARK: - bundleIDPrefix

    func test_bundleIDPrefix_matchesExact() {
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "com.acme.Widget.plist",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .bundleIDPrefix
        ))
    }

    func test_bundleIDPrefix_matchesSubdomainSuffix() {
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "com.acme.Widget.helper.plist",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .bundleIDPrefix
        ))
    }

    func test_bundleIDPrefix_rejectsSharedPrefixWithoutDot() {
        // com.acme.WidgetPro should NOT match com.acme.Widget
        XCTAssertFalse(LeftoverFinder.nameMatches(
            fileName: "com.acme.WidgetPro.plist",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .bundleIDPrefix
        ))
    }

    func test_bundleIDPrefix_nonPlistExtensionIsPartOfMatchTarget() {
        // Only .plist is stripped, so the full name is matched — which makes this a
        // valid prefix-style match (`com.acme.Widget` + "." + "log").
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "com.acme.Widget.log",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .bundleIDPrefix
        ))
    }

    // MARK: - loose

    func test_loose_matchesAppNameExact() {
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "Widget",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .loose
        ))
    }

    func test_loose_matchesBundleIDSubstring() {
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "group.com.acme.Widget",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .loose
        ))
    }

    func test_loose_rejectsShortAppName() {
        // "Go" is 2 chars — too short to match on name.
        XCTAssertFalse(LeftoverFinder.nameMatches(
            fileName: "Go",
            bundleID: "com.google.Go",
            appName: "Go",
            mode: .loose
        ))
    }

    func test_loose_matchesNameAsPrefix() {
        XCTAssertTrue(LeftoverFinder.nameMatches(
            fileName: "Widget.settings",
            bundleID: "com.acme.Widget",
            appName: "Widget",
            mode: .loose
        ))
    }
}

final class LeftoverFinderFixtureTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CleanMeTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func test_find_matchesAcrossMultipleLocations() async throws {
        let prefs = tempRoot.appendingPathComponent("Preferences")
        let caches = tempRoot.appendingPathComponent("Caches")
        let containers = tempRoot.appendingPathComponent("Containers")
        for dir in [prefs, caches, containers] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let bid = "com.acme.Widget"

        // Hits.
        let prefPlist = prefs.appendingPathComponent("\(bid).plist")
        try Data("x".utf8).write(to: prefPlist)

        let cacheDir = caches.appendingPathComponent(bid)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 2048).write(to: cacheDir.appendingPathComponent("data.bin"))

        let containerDir = containers.appendingPathComponent(bid)
        try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)

        // Misses.
        try Data("y".utf8).write(to: prefs.appendingPathComponent("com.other.app.plist"))
        try FileManager.default.createDirectory(
            at: containers.appendingPathComponent("com.acme.WidgetPro"),
            withIntermediateDirectories: true
        )

        let locations: [LeftoverFinder.SearchLocation] = [
            .init(url: prefs, kind: .preferences, mode: .bundleIDPrefix, requiresAdmin: false),
            .init(url: caches, kind: .caches, mode: .bundleIDPrefix, requiresAdmin: false),
            .init(url: containers, kind: .containers, mode: .bundleIDExact, requiresAdmin: false),
        ]

        let finder = LeftoverFinder(locations: locations)
        let app = InstalledApp(name: "Widget", bundleID: bid, version: "1.0", url: URL(fileURLWithPath: "/Applications/Widget.app"))

        let matches = await finder.find(for: app)
        XCTAssertEqual(matches.count, 3)
        let names = matches.map(\.url.lastPathComponent).sorted()
        XCTAssertEqual(names, [bid, bid, "\(bid).plist"].sorted())
        XCTAssertEqual(Set(matches.map(\.kind)), [.preferences, .caches, .containers])

        // Cache directory size should be at least the 2KB payload we wrote.
        // Allocated size can exceed logical size due to block rounding; we only assert lower bound.
        let cacheMatch = matches.first { $0.kind == .caches }
        XCTAssertGreaterThanOrEqual(cacheMatch?.sizeBytes ?? 0, 2048)
    }
}
