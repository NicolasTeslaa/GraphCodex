import Foundation

enum AgentRole: String, CaseIterable, Codable, Identifiable, Sendable {
    case backend, frontend, uiux, qa, product, research, marketing, generalist
    var id: String { rawValue }

    var title: String {
        switch self {
        case .backend: "Dev Backend"
        case .frontend: "Dev Frontend"
        case .uiux: "UI/UX"
        case .qa: "QA"
        case .product: "Product / PM"
        case .research: "Research"
        case .marketing: "Marketing"
        case .generalist: "Generalist"
        }
    }
}

enum AgentPriority: Int, CaseIterable, Codable, Identifiable, Sendable {
    case low = 0, normal = 1, high = 2, urgent = 3
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: "Baixa"
        case .normal: "Normal"
        case .high: "Alta"
        case .urgent: "Urgente"
        }
    }
}

enum AgentTemplate: String, CaseIterable, Codable, Identifiable, Sendable {
    case implementFeature, fixBug, refactor, onboarding, researchCompetitor, documentation, architecture, analyzeIssue
    var id: String { rawValue }

    var title: String {
        switch self {
        case .implementFeature: "Implement feature"
        case .fixBug: "Fix bug"
        case .refactor: "Refactor"
        case .onboarding: "Create onboarding"
        case .researchCompetitor: "Research competitor"
        case .documentation: "Write documentation"
        case .architecture: "Setup architecture"
        case .analyzeIssue: "Analyze issue"
        }
    }

    var instruction: String {
        switch self {
        case .implementFeature: "Implemente o objetivo descrito. Primeiro inspecione o código e as instruções do projeto, depois proponha uma mudança pequena e completa."
        case .fixBug: "Investigue o problema descrito, reproduza-o com um teste e corrija a causa sem ampliar o escopo."
        case .refactor: "Refatore o trecho descrito preservando o comportamento. Identifique os consumidores e valide a mudança com testes."
        case .onboarding: "Projete e implemente uma experiência de onboarding clara, acessível e alinhada à interface existente."
        case .researchCompetitor: "Pesquise as fontes indicadas, diferencie fatos de inferências e entregue uma síntese com links e data."
        case .documentation: "Escreva documentação baseada no comportamento real do código e mantenha exemplos verificáveis."
        case .architecture: "Inspecione os limites atuais, compare opções de arquitetura e proponha uma evolução incremental com trade-offs."
        case .analyzeIssue: "Analise o problema informado, encontre o fluxo responsável e apresente evidências e critérios para uma correção."
        }
    }

}

enum AgentContextSource: Equatable, Sendable {
    case blank
    case template(AgentTemplate)
    case project(selectedFilePaths: [String])
    case cloneFullHistory(threadID: String)
    case cloneSummary(threadID: String, summary: String)
}

struct AgentDraft: Equatable, Sendable {
    var name: String
    var goal: String
    var role: AgentRole
    var priority: AgentPriority
    var tags: [String]
    var projectID: String
    var workingDirectory: String
    var contextSource: AgentContextSource
    var customPrompt: String

    init(name: String, goal: String, role: AgentRole, priority: AgentPriority = .normal,
         tags: [String] = [], projectID: String, workingDirectory: String,
         contextSource: AgentContextSource = .blank, customPrompt: String = "") {
        self.name = name
        self.goal = goal
        self.role = role
        self.priority = priority
        self.tags = tags
        self.projectID = projectID
        self.workingDirectory = workingDirectory
        self.contextSource = contextSource
        self.customPrompt = customPrompt
    }
}
