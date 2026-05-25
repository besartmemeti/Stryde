import Foundation

struct PersistedRunState: Codable {
    let startTime: Date
    let goalDistance: Double?
    let distance: Double
    let snapshots: [LocationSnapshot]
}

enum RunRecoveryStore {
    private static var fileURL: URL {
        URL.documentsDirectory.appendingPathComponent("stryde_active_run.json")
    }

    static var hasSavedRun: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func save(_ state: PersistedRunState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> PersistedRunState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PersistedRunState.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
