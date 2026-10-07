import Foundation

struct DepartmentPlacement: Codable, Hashable, Sendable {
    var x: Double
    var z: Double
    var scale: Double
}

struct OfficeLayout: Codable, Hashable, Sendable {
    var departments: [String: DepartmentPlacement]

    init(departments: [String: DepartmentPlacement] = [:]) {
        self.departments = departments
    }
}

struct GraphCodexPreferences: Codable, Hashable, Sendable {
    var inactivityMinutes: Double
    var defaultMode: String
    var soundEnabled: Bool
    var reduceMotion: Bool

    init(inactivityMinutes: Double = 1, defaultMode: String = "map", soundEnabled: Bool = false, reduceMotion: Bool = false) {
        self.inactivityMinutes = inactivityMinutes
        self.defaultMode = defaultMode
        self.soundEnabled = soundEnabled
        self.reduceMotion = reduceMotion
    }
}

struct GraphCodexSnapshot: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var projects: [Project]
    var sessionMetadata: [String: SessionMetadata]
    var officeLayout: OfficeLayout
    var preferences: GraphCodexPreferences

    init(
        schemaVersion: Int = currentSchemaVersion,
        projects: [Project] = [],
        sessionMetadata: [String: SessionMetadata] = [:],
        officeLayout: OfficeLayout = OfficeLayout(),
        preferences: GraphCodexPreferences = GraphCodexPreferences()
    ) {
        self.schemaVersion = schemaVersion
        self.projects = projects
        self.sessionMetadata = sessionMetadata
        self.officeLayout = officeLayout
        self.preferences = preferences
    }
}

enum GraphCodexStoreError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "Os dados locais usam uma versão mais nova (\(version)) e foram preservados sem alterações. Atualize o GraphCodex para carregá-los."
        }
    }
}

struct GraphCodexStore {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("GraphCodex", isDirectory: true).appendingPathComponent("graphcodex.json")
    }

    func load() throws -> GraphCodexSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return GraphCodexSnapshot() }
        let data = try Data(contentsOf: fileURL)
        let snapshot = try JSONDecoder().decode(GraphCodexSnapshot.self, from: data)
        guard snapshot.schemaVersion <= GraphCodexSnapshot.currentSchemaVersion else {
            throw GraphCodexStoreError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    func save(_ snapshot: GraphCodexSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}
