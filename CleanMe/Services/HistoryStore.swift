import Foundation

/// Persists `UninstallRecord` values to `~/Library/Application Support/CleanMe/history.json`.
/// All I/O happens off the main actor.
actor HistoryStore {
    private let url: URL
    private let fm: FileManager

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fm = fileManager
        if let fileURL {
            self.url = fileURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("CleanMe", isDirectory: true)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            self.url = dir.appendingPathComponent("history.json")
        }
    }

    func load() -> [UninstallRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([UninstallRecord].self, from: data)) ?? []
    }

    func append(_ record: UninstallRecord) throws {
        var existing = load()
        existing.insert(record, at: 0)
        try save(existing)
    }

    func remove(id: UUID) throws {
        let filtered = load().filter { $0.id != id }
        try save(filtered)
    }

    func clear() throws {
        try save([])
    }

    private func save(_ records: [UninstallRecord]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: url, options: .atomic)
    }
}
