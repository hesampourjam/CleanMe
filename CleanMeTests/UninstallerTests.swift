import XCTest
@testable import CleanMe

final class UninstallerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CleanMeUninst-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func test_systemProtectedApp_throws() async {
        let app = InstalledApp(
            name: "Finder",
            bundleID: "com.apple.finder",
            version: "1",
            url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        )
        let uninstaller = Uninstaller()
        do {
            _ = try await uninstaller.uninstall(app: app, leftovers: [])
            XCTFail("Expected throw")
        } catch UninstallError.systemProtected {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_uninstall_movesBundleAndLeftoversToTrash() async throws {
        // Build a fake app bundle + a fake leftover file in our temp dir.
        let bid = "dev.appcleaner.FakeWidget-\(UUID().uuidString)"
        let appURL = tempRoot.appendingPathComponent("FakeWidget.app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": bid, "CFBundleName": "FakeWidget"],
            format: .xml,
            options: 0
        ).write(to: contents.appendingPathComponent("Info.plist"))

        let leftoverURL = tempRoot.appendingPathComponent("\(bid).plist")
        try Data("hello".utf8).write(to: leftoverURL)

        let app = InstalledApp(name: "FakeWidget", bundleID: bid, version: "1", url: appURL, sizeBytes: 512)
        let leftover = AssociatedFile(url: leftoverURL, kind: .preferences, sizeBytes: 5, requiresAdmin: false)
        let adminLeftover = AssociatedFile(
            url: URL(fileURLWithPath: "/Library/LaunchDaemons/\(bid).plist"),
            kind: .launchDaemons,
            sizeBytes: 100,
            requiresAdmin: true
        )

        let uninstaller = Uninstaller()
        let result = try await uninstaller.uninstall(app: app, leftovers: [leftover, adminLeftover])

        // Admin-required items are recorded but not trashed.
        XCTAssertEqual(result.record.skippedAdminItems, [adminLeftover.url])

        // Original paths should be gone.
        XCTAssertFalse(FileManager.default.fileExists(atPath: appURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: leftoverURL.path))

        // Record should include both original URLs in order (app first).
        XCTAssertEqual(result.record.items.count, 2)
        XCTAssertEqual(result.record.items[0].originalURL.standardizedFileURL, appURL.standardizedFileURL)
        XCTAssertEqual(result.record.items[1].originalURL.standardizedFileURL, leftoverURL.standardizedFileURL)

        // Both should have a trashedURL set (recycle succeeded).
        for item in result.record.items {
            XCTAssertNotNil(item.trashedURL, "Expected a trash URL for \(item.originalURL.lastPathComponent)")
        }

        // Clean up the trashed copies so they don't accumulate in Trash across test runs.
        for item in result.record.items {
            if let url = item.trashedURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
