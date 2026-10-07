import AppKit
import Combine
import Foundation

@MainActor
final class CodexMonitor: ObservableObject {
    @Published private(set) var sessions: [CodexSession] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var connectionError: String?
    @Published private(set) var integrationNotice: String?
    @Published var selectedSessionID: String?
    @Published var selectedProjectID: String?
    @Published var officeMode: OfficeMode = .map
    @Published var refreshInterval: Double = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 10
    @Published var inactivityMinutes: Double = UserDefaults.standard.object(forKey: "inactivityMinutes") as? Double ?? 1
    @Published private(set) var soundEnabled = false
    @Published private(set) var reduceMotion = false

    private let client = CodexAppServerClient()
    private let creationService: AgentCreationService
    private var repository: GraphCodexWorkspaceRepository?
    private var timer: Timer?

    init() {
        creationService = AgentCreationService(transport: client)
        do {
            repository = try GraphCodexWorkspaceRepository()
            if let repository {
                let preferences = repository.snapshot.preferences
                officeMode = OfficeMode(rawValue: preferences.defaultMode) ?? .map
                inactivityMinutes = preferences.inactivityMinutes
                soundEnabled = preferences.soundEnabled
                reduceMotion = preferences.reduceMotion
            }
        } catch {
            connectionError = "Não consegui ler os metadados locais; o arquivo foi preservado. \(error.localizedDescription)"
        }
        client.onServerNotice = { [weak self] message in
            Task { @MainActor [weak self] in self?.integrationNotice = message }
        }
        startRefreshing()
    }

    var attentionCount: Int { sessions.filter { $0.state == .attention }.count }
    var workingCount: Int { sessions.filter { $0.state == .working }.count }
    var completedCount: Int { sessions.filter { $0.state == .complete }.count }
    var currentCount: Int { sessions.filter { $0.state != .complete }.count }
    var selectedSession: CodexSession? { sessions.first { $0.id == selectedSessionID } }
    var projects: [Project] { projectGroups.map(\.project) }
    var projectGroups: [ProjectGroup] {
        SessionOrganizer.group(sessions, projects: repository?.snapshot.projects ?? [],
                              metadata: repository?.snapshot.sessionMetadata ?? [:])
    }
    var idleCount: Int { sessions.filter { $0.state == .quiet }.count }

    func startRefreshing() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(5, refreshInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        do {
            let oldAttentionCount = attentionCount
            sessions = try await client.loadSessions(inactivityMinutes: inactivityMinutes)
            lastUpdated = Date()
            if repository != nil { connectionError = nil }
            if soundEnabled, attentionCount > oldAttentionCount { NSSound.beep() }
        } catch {
            connectionError = error.localizedDescription
        }
        isRefreshing = false
    }

    func select(_ session: CodexSession) {
        selectedSessionID = session.id
    }

    func open(_ session: CodexSession) {
        select(session)
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex"),
              let url = URL(string: "codex://threads/\(session.id)") else {
            connectionError = "Não consegui localizar o app Codex para abrir esta sessão."
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in self?.connectionError = "Não foi possível abrir a sessão: \(error.localizedDescription)" }
        }
    }

    func focus(project: Project) {
        selectedProjectID = project.id
        officeMode = .focus
    }

    func clearFocus() {
        selectedProjectID = nil
        officeMode = .map
    }

    func saveProject(_ project: Project) throws {
        try requireRepository().saveProject(project)
        integrationNotice = nil
    }

    func assign(_ session: CodexSession, to projectID: String?) throws {
        try requireRepository().assign(sessionID: session.id, to: projectID)
        integrationNotice = nil
    }

    func setPriority(_ priority: Int, for session: CodexSession) throws {
        try requireRepository().updateMetadata(for: session.id) { $0.priority = priority }
    }

    func toggleFavorite(for session: CodexSession) throws {
        try requireRepository().updateMetadata(for: session.id) { $0.isFavorite.toggle() }
    }

    func metadata(for session: CodexSession) -> SessionMetadata {
        repository?.snapshot.sessionMetadata[session.id] ?? SessionMetadata()
    }

    func archive(_ session: CodexSession) async throws {
        _ = try await client.request(method: "thread/archive", params: ["threadId": session.id])
        await refresh()
    }

    func startAgent(_ draft: AgentDraft, approvedPrompt: String) async throws -> String {
        do {
            let threadID = try await creationService.start(draft, approvedPrompt: approvedPrompt)
            var metadata = SessionMetadata(projectOverrideID: draft.projectID, displayName: draft.name,
                                          role: draft.role.title, priority: draft.priority.rawValue,
                                          tags: draft.tags)
            metadata.startupError = nil
            try requireRepository().updateMetadata(for: threadID) { $0 = metadata }
            await refresh()
            return threadID
        } catch let error as AgentCreationError {
            if case .turnStartFailed(let threadID, let underlying) = error {
                try? repository?.updateMetadata(for: threadID) { $0.startupError = underlying.localizedDescription }
            }
            throw error
        }
    }

    private func requireRepository() throws -> GraphCodexWorkspaceRepository {
        guard let repository else {
            throw CodexConnectionError.rpc(connectionError ?? "Os metadados locais estão indisponíveis.")
        }
        return repository
    }

    func updateRefreshInterval(_ value: Double) {
        refreshInterval = value
        UserDefaults.standard.set(value, forKey: "refreshInterval")
        startRefreshing()
    }

    func updateInactivityMinutes(_ value: Double) {
        inactivityMinutes = value
        UserDefaults.standard.set(value, forKey: "inactivityMinutes")
        persistPreferences()
        Task { await refresh() }
    }

    func updateDefaultMode(_ mode: OfficeMode) { persistPreferences(defaultMode: mode.rawValue) }
    func updateSoundEnabled(_ enabled: Bool) { soundEnabled = enabled; persistPreferences() }
    func updateReduceMotion(_ enabled: Bool) { reduceMotion = enabled; persistPreferences() }
    func report(_ error: Error) { connectionError = error.localizedDescription }

    func dismissNotice(_ message: String) {
        if connectionError == message { connectionError = nil }
        if integrationNotice == message { integrationNotice = nil }
    }

    private func persistPreferences(defaultMode: String? = nil) {
        let preferences = GraphCodexPreferences(inactivityMinutes: inactivityMinutes,
                                                defaultMode: defaultMode ?? officeMode.rawValue,
                                                soundEnabled: soundEnabled, reduceMotion: reduceMotion)
        do { try repository?.savePreferences(preferences) }
        catch { connectionError = "Não foi possível salvar as preferências: \(error.localizedDescription)" }
    }
}
