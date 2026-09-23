import AppKit
import Combine
import Foundation

@MainActor
final class CodexMonitor: ObservableObject {
    @Published private(set) var sessions: [CodexSession] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var connectionError: String?
    @Published var selectedSessionID: String?
    @Published var refreshInterval: Double = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 10
    @Published var inactivityMinutes: Double = UserDefaults.standard.object(forKey: "inactivityMinutes") as? Double ?? 1

    private let client = CodexAppServerClient()
    private var timer: Timer?

    init() { startRefreshing() }

    var attentionCount: Int { sessions.filter { $0.state == .attention }.count }
    var workingCount: Int { sessions.filter { $0.state == .working }.count }
    var completedCount: Int { sessions.filter { $0.state == .complete }.count }
    var currentCount: Int { sessions.filter { $0.state != .complete }.count }
    var selectedSession: CodexSession? { sessions.first { $0.id == selectedSessionID } }

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
            sessions = try await client.loadSessions(inactivityMinutes: inactivityMinutes)
            lastUpdated = Date()
            connectionError = nil
        } catch {
            connectionError = error.localizedDescription
        }
        isRefreshing = false
    }

    func open(_ session: CodexSession) {
        selectedSessionID = session.id
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

    func updateRefreshInterval(_ value: Double) {
        refreshInterval = value
        UserDefaults.standard.set(value, forKey: "refreshInterval")
        startRefreshing()
    }

    func updateInactivityMinutes(_ value: Double) {
        inactivityMinutes = value
        UserDefaults.standard.set(value, forKey: "inactivityMinutes")
        Task { await refresh() }
    }
}
