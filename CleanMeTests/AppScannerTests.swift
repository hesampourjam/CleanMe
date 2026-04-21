import XCTest
@testable import CleanMe

final class AppScannerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CleanMeScan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func test_scan_picksUpFakeAppBundle() async throws {
        let appURL = try makeFakeApp(
            named: "Widget",
            bundleID: "com.acme.Widget",
            version: "2.1",
            in: tempRoot
        )

        let scanner = AppScanner(searchPaths: [tempRoot])
        let apps = await scanner.scan()

        XCTAssertEqual(apps.count, 1)
        let widget = try XCTUnwrap(apps.first)
        XCTAssertEqual(widget.name, "Widget")
        XCTAssertEqual(widget.bundleID, "com.acme.Widget")
        XCTAssertEqual(widget.version, "2.1")
        XCTAssertEqual(widget.url.standardizedFileURL, appURL.standardizedFileURL)
    }

    func test_scan_ignoresNonAppEntries() async throws {
        _ = try makeFakeApp(named: "Widget", bundleID: "com.acme.Widget", version: "1", in: tempRoot)
        try Data("noise".utf8).write(to: tempRoot.appendingPathComponent("README.txt"))
        try FileManager.default.createDirectory(
            at: tempRoot.appendingPathComponent("NotAnApp"),
            withIntermediateDirectories: true
        )

        let scanner = AppScanner(searchPaths: [tempRoot])
        let apps = await scanner.scan()
        XCTAssertEqual(apps.map(\.name), ["Widget"])
    }

    func test_folderSize_reflectsPayload() async throws {
        let dir = tempRoot.appendingPathComponent("payload", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let payload = Data(repeating: 0xAB, count: 8192)
        try payload.write(to: dir.appendingPathComponent("a.bin"))
        try payload.write(to: dir.appendingPathComponent("b.bin"))

        let scanner = AppScanner(searchPaths: [])
        let size = await scanner.folderSize(of: dir)
        XCTAssertGreaterThanOrEqual(size, Int64(payload.count * 2))
    }

    // MARK: - Helpers

    private func makeFakeApp(named name: String, bundleID: String, version: String, in root: URL) throws -> URL {
        let app = root.appendingPathComponent("\(name).app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name,
            "CFBundleShortVersionString": version,
            "CFBundleExecutable": name,
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }
}
