import Foundation

enum SessionState: String, CaseIterable, Identifiable {
    case working, attention, complete, quiet, unknown
    var id: String { rawValue }

    var label: String {
        switch self {
        case .working: "Trabalhando"
        case .attention: "Precisa de você"
        case .complete: "Concluída"
        case .quiet: "Sem atividade"
        case .unknown: "Estado desconhecido"
        }
    }

    var symbol: String {
        switch self {
        case .working: "hammer.fill"
        case .attention: "exclamationmark.bubble.fill"
        case .complete: "checkmark.seal.fill"
        case .quiet: "moon.zzz.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var colorHex: UInt32 {
        switch self {
        case .working: 0x73E1B5
        case .attention: 0xFF7A68
        case .complete: 0xA7A0FF
        case .quiet: 0xF4C86A
        case .unknown: 0x95A3B8
        }
    }
}

struct CodexSession: Identifiable, Hashable {
    let id: String
    let name: String?
    let cwd: String
    let updatedAt: Date
    let state: SessionState
    let reason: String?
    let project: String
    let promptSummary: String?

    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        return project.isEmpty ? "Sessão Codex" : project
    }

    var relativeActivity: String {
        let seconds = max(0, Int(Date().timeIntervalSince(updatedAt)))
        if seconds < 60 { return "agora" }
        if seconds < 3_600 { return "há \(seconds / 60) min" }
        if seconds < 86_400 { return "há \(seconds / 3_600) h" }
        return "há \(seconds / 86_400) d"
    }
}

enum SessionFilter: String, CaseIterable, Identifiable {
    case current = "Ativas"
    case working = "Trabalhando"
    case attention = "Atenção"
    case all = "Recentes"
    case complete = "Concluídas"
    var id: String { rawValue }

    func includes(_ session: CodexSession) -> Bool {
        switch self {
        case .current: session.state != .complete
        case .working: session.state == .working
        case .attention: session.state == .attention
        case .all: true
        case .complete: session.state == .complete
        }
    }
}
