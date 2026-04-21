import XCTest
@testable import CleanMe

final class OrphanDetectorInferTests: XCTestCase {
    func test_inferBundleID_stripsPlist() {
        XCTAssertEqual(OrphanDetector.inferBundleID(fromFileName: "com.acme.Widget.plist"), "com.acme.Widget")
    }

    func test_inferBundleID_requiresDottedName() {
        XCTAssertNil(OrphanDetector.inferBundleID(fromFileName: "Widget"))
    }

    func test_inferBundleID_skipsDotfiles() {
        XCTAssertNil(OrphanDetector.inferBundleID(fromFileName: ".DS_Store"))
    }

    func test_inferBundleID_keepsReverseDNS() {
        XCTAssertEqual(OrphanDetector.inferBundleID(fromFileName: "com.acme.Widget"), "com.acme.Widget")
    }

    func test_inferBundleID_rejectsLongFirstComponent() {
        // First component > 10 chars is unlikely to be a TLD-style prefix.
        XCTAssertNil(OrphanDetector.inferBundleID(fromFileName: "verylongprefix.acme.Widget"))
    }

    func test_inferBundleID_rejectsNonLetterFirstComponent() {
        XCTAssertNil(OrphanDetector.inferBundleID(fromFileName: "123.acme.Widget"))
    }
}

final class OrphanDetectorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CleanMeOrphan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func test_findOrphans_groupsUnknownBundles() async throws {
        let prefs = tempRoot.appendingPathComponent("Preferences")
        try FileManager.default.createDirectory(at: prefs, withIntermediateDirectories: true)

        // Known (installed) bundle — should be filtered out.
        try Data().write(to: prefs.appendingPathComponent("com.acme.Widget.plist"))
        // Orphan.
        try Data("x".utf8).write(to: prefs.appendingPathComponent("com.ghost.Spooky.plist"))
        // Junk that can't be parsed as a bundle ID.
        try Data().write(to: prefs.appendingPathComponent("README"))

        let locations: [LeftoverFinder.SearchLocation] = [
            .init(url: prefs, kind: .preferences, mode: .bundleIDPrefix, requiresAdmin: false)
        ]
        let detector = OrphanDetector(locations: locations)
        let orphans = await detector.findOrphans(installedBundleIDs: ["com.acme.Widget"])

        XCTAssertEqual(orphans.count, 1)
        XCTAssertEqual(orphans.first?.id, "com.ghost.Spooky")
    }
}
