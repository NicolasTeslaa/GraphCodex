import Foundation

enum ProjectKind: String, Codable, CaseIterable, Identifiable {
    case product
    case client
    case research
    case automation
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .product: "Produto"
        case .client: "Cliente"
        case .research: "Pesquisa"
        case .automation: "Automação"
        case .general: "Geral"
        }
    }
}

struct Project: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var description: String
    var instructions: String
    var colorHex: UInt32
    var icon: String
    var kind: ProjectKind
    var tags: [String]
    var workingDirectory: String?
    var isAutomaticallyGrouped: Bool

    init(
        id: String,
        name: String,
        description: String = "",
        instructions: String = "",
        colorHex: UInt32 = 0xB2A3FF,
        icon: String = "square.stack.3d.up.fill",
        kind: ProjectKind = .general,
        tags: [String] = [],
        workingDirectory: String? = nil,
        isAutomaticallyGrouped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.instructions = instructions
        self.colorHex = colorHex
        self.icon = icon
        self.kind = kind
        self.tags = tags
        self.workingDirectory = workingDirectory
        self.isAutomaticallyGrouped = isAutomaticallyGrouped
    }

    static func automatic(for path: String) -> Project {
        let canonicalPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return Project(
            id: canonicalPath,
            name: URL(fileURLWithPath: canonicalPath).lastPathComponent,
            workingDirectory: canonicalPath,
            isAutomaticallyGrouped: true
        )
    }
}

struct SessionMetadata: Codable, Hashable, Sendable {
    var projectOverrideID: String?
    var displayName: String?
    var role: String?
    var priority: Int
    var isFavorite: Bool
    var tags: [String]
    var startupError: String?

    init(
        projectOverrideID: String? = nil,
        displayName: String? = nil,
        role: String? = nil,
        priority: Int = 0,
        isFavorite: Bool = false,
        tags: [String] = [],
        startupError: String? = nil
    ) {
        self.projectOverrideID = projectOverrideID
        self.displayName = displayName
        self.role = role
        self.priority = priority
        self.isFavorite = isFavorite
        self.tags = tags
        self.startupError = startupError
    }
}

struct ProjectGroup: Identifiable, Hashable, Sendable {
    var project: Project
    var sessions: [CodexSession]

    var id: String { project.id }
    var attentionCount: Int { sessions.filter { $0.state == .attention }.count }
    var workingCount: Int { sessions.filter { $0.state == .working }.count }
}
