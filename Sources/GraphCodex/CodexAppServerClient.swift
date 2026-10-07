import AppKit
import Foundation

enum CodexConnectionError: LocalizedError {
    case executableNotFound
    case processNotRunning
    case serverClosed
    case rpc(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Não encontrei o executável do Codex. Instale ou atualize o app Codex e tente novamente."
        case .processNotRunning:
            "O serviço local do Codex não iniciou."
        case .serverClosed:
            "O serviço local do Codex encerrou a conexão."
        case .rpc(let message): message
        }
    }
}

/// Cliente JSON-RPC somente de leitura para o app-server local do Codex.
/// As chamadas de pipe ficam em uma fila de fundo e não bloqueiam a interface.
final class CodexAppServerClient: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.graphcodex.app-server")
    private var process: Process?
    private var input: Pipe?
    private var output: Pipe?
    private var bufferedOutput = Data()
    private var nextRequestID = 1
    private var initialized = false
    var onServerNotice: (@Sendable (String) -> Void)?

    func loadSessions(inactivityMinutes: Double) async throws -> [CodexSession] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.connectIfNeeded()
                    let now = Date()
                    // The app-server lists the whole local history. Use the rollout file's
                    // modification time as the live activity signal for threads loaded by
                    // the separate Codex Desktop process (whose app-server status is `notLoaded`).
                    let threads = try self.listThreads().filter {
                        now.timeIntervalSince($0.updatedAt) <= 60 * 60 * 24
                            || ($0.status["activeFlags"] as? [String])?.isEmpty == false
                    }
                    let recent = threads
                        .filter { now.timeIntervalSince($0.updatedAt) < 60 * 60 * 24 * 14 }
                        .prefix(60)

                    var latestTurns: [String: TurnSummary] = [:]
                    for thread in recent {
                        if let summary = try? self.latestTurn(threadID: thread.id) {
                            latestTurns[thread.id] = summary
                        }
                    }

                    let sessions = threads.map { thread -> CodexSession in
                        let result = Self.classify(
                            threadStatus: thread.status,
                            latestTurn: latestTurns[thread.id],
                            updatedAt: thread.updatedAt,
                            now: now,
                            inactivityMinutes: inactivityMinutes
                        )
                        return CodexSession(
                            id: thread.id,
                            name: thread.name,
                            cwd: thread.cwd,
                            updatedAt: thread.updatedAt,
                            state: result.state,
                            reason: result.reason,
                            project: URL(fileURLWithPath: thread.cwd).lastPathComponent,
                            promptSummary: latestTurns[thread.id]?.promptSummary
                        )
                    }
                    continuation.resume(returning: sessions)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func connectIfNeeded() throws {
        if process?.isRunning == true, initialized { return }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: try Self.findCodexExecutable())
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        if environment["CODEX_HOME"] == nil { environment["CODEX_HOME"] = NSHomeDirectory() + "/.codex" }
        process.environment = environment
        try process.run()

        self.process = process
        self.input = input
        self.output = output
        self.bufferedOutput = Data()
        self.initialized = false

        let response = try requestSync(method: "initialize", params: [
            "clientInfo": ["name": "GraphCodex", "title": "GraphCodex", "version": "0.1.0"],
            "capabilities": ["experimentalApi": true]
        ])
        guard response["result"] != nil else { throw Self.rpcError(from: response) }
        try sendNotification(method: "initialized", params: [:])
        self.initialized = true
    }

    private static func findCodexExecutable() throws -> String {
        var resourcesPath: String?
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex"),
           let resources = Bundle(url: appURL)?.resourceURL {
            resourcesPath = resources.path
        }
        guard let found = CodexExecutableLocator.locate(appResourcesPath: resourcesPath) else {
            throw CodexConnectionError.executableNotFound
        }
        return found
    }

    private func listThreads() throws -> [ThreadRecord] {
        var cursor: String?
        var records: [ThreadRecord] = []
        repeat {
            var params: [String: Any] = [
                "limit": 100,
                "archived": false,
                "sortKey": "recency_at",
                "sortDirection": "desc"
            ]
            if let cursor { params["cursor"] = cursor }
            let response = try requestSync(method: "thread/list", params: params)
            guard let result = response["result"] as? [String: Any],
                  let data = result["data"] as? [[String: Any]] else {
                throw Self.rpcError(from: response)
            }
            records += data.compactMap(ThreadRecord.init(json:))
            cursor = result["nextCursor"] as? String
        } while cursor != nil && records.count < 2_000
        return records
    }

    private func latestTurn(threadID: String) throws -> TurnSummary? {
        let response = try requestSync(method: "thread/turns/list", params: [
            "threadId": threadID,
            "limit": 1,
            "sortDirection": "desc",
            "itemsView": "summary"
        ])
        guard let result = response["result"] as? [String: Any],
              let turns = result["data"] as? [[String: Any]],
              let turn = turns.first else { return nil }
        let items = turn["items"] as? [[String: Any]] ?? []
        let hasQuestions = items.contains { item in
            (item["type"] as? String) == "agentMessage" && !(item["questions"] as? [[String: Any]] ?? []).isEmpty
        }
        let lastPrompt = items.last(where: { ($0["type"] as? String) == "userMessage" })
            .flatMap { $0["content"] as? [[String: Any]] }?
            .compactMap { $0["text"] as? String }
            .joined(separator: " ")
        let promptSummary = lastPrompt.flatMap(Self.shortPromptSummary)
        return TurnSummary(status: turn["status"] as? String, hasQuestions: hasQuestions, promptSummary: promptSummary)
    }

    private static func shortPromptSummary(_ prompt: String) -> String? {
        let compact = prompt
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        if compact.count <= 100 { return compact }
        let prefix = String(compact.prefix(100))
        let wholeWords = prefix.split(separator: " ").dropLast().joined(separator: " ")
        return (wholeWords.isEmpty ? prefix : wholeWords) + "…"
    }

    private static func classify(
        threadStatus: [String: Any],
        latestTurn: TurnSummary?,
        updatedAt: Date,
        now: Date,
        inactivityMinutes: Double
    ) -> (state: SessionState, reason: String?) {
        let type = threadStatus["type"] as? String ?? "unknown"
        let flags = threadStatus["activeFlags"] as? [String] ?? []
        if flags.contains("waitingOnApproval") { return (.attention, "Aguardando aprovação") }
        if flags.contains("waitingOnUserInput") { return (.attention, "Aguardando sua resposta") }
        if latestTurn?.status == "inProgress", latestTurn?.hasQuestions == true {
            return (.attention, "O Codex fez uma pergunta")
        }
        if type == "systemError" || latestTurn?.status == "failed" {
            return (.attention, "O Codex encontrou um erro")
        }
        if latestTurn?.status == "interrupted" {
            if now.timeIntervalSince(updatedAt) <= inactivityMinutes * 60 { return (.working, nil) }
            return (.attention, "Sem atividade há mais de \(Int(inactivityMinutes)) min")
        }
        if type == "active" || latestTurn?.status == "inProgress" {
            if now.timeIntervalSince(updatedAt) > inactivityMinutes * 60 {
                return (.attention, "Sem atividade há mais de \(Int(inactivityMinutes)) min")
            }
            return (.working, nil)
        }
        if latestTurn?.status == "completed" || type == "idle" { return (.complete, nil) }
        if now.timeIntervalSince(updatedAt) > inactivityMinutes * 60 {
            return (.quiet, "Última atividade há \(Int(now.timeIntervalSince(updatedAt) / 60)) min")
        }
        return (.unknown, "O Codex ainda não informou o estado desta sessão")
    }

    fileprivate func requestSync(method: String, params: [String: Any]) throws -> [String: Any] {
        let id = nextRequestID
        nextRequestID += 1
        try write(["id": id, "method": method, "params": params])
        while true {
            guard let data = try readLine().data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let handled = CodexServerRequestRouter.response(for: object) {
                try write(handled.response)
                if let notice = handled.notice { onServerNotice?(notice) }
                continue
            }
            if (object["id"] as? Int) == id { return object }
        }
    }

    private func sendNotification(method: String, params: [String: Any]) throws {
        try write(["method": method, "params": params])
    }

    private func write(_ object: [String: Any]) throws {
        guard let input else { throw CodexConnectionError.processNotRunning }
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func readLine() throws -> String {
        guard let output else { throw CodexConnectionError.processNotRunning }
        while true {
            if let newline = bufferedOutput.firstIndex(of: 0x0A) {
                let line = bufferedOutput[..<newline]
                bufferedOutput.removeSubrange(...newline)
                return String(decoding: line, as: UTF8.self)
            }
            let next = output.fileHandleForReading.availableData
            if next.isEmpty { throw CodexConnectionError.serverClosed }
            bufferedOutput.append(next)
        }
    }

    private static func rpcError(from response: [String: Any]) -> Error {
        let error = response["error"] as? [String: Any]
        return CodexConnectionError.rpc(error?["message"] as? String ?? "A solicitação ao Codex falhou.")
    }

    deinit { process?.terminate() }
}

extension CodexAppServerClient: CodexTransport {
    func request(method: String, params: [String: Any]) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.connectIfNeeded()
                    let response = try self.requestSync(method: method, params: params)
                    guard let result = response["result"] as? [String: Any] else {
                        throw Self.rpcError(from: response)
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private struct ThreadRecord {
    let id: String
    let name: String?
    let cwd: String
    let updatedAt: Date
    let status: [String: Any]

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else { return nil }
        self.id = id
        self.name = json["name"] as? String
        self.cwd = json["cwd"] as? String ?? ""
        let indexedUpdate = Date(timeIntervalSince1970: json["updatedAt"] as? Double ?? 0)
        let rolloutPath = json["path"] as? String
        let fileUpdate = rolloutPath.flatMap { path -> Date? in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
            return attributes[.modificationDate] as? Date
        }
        // `updatedAt` in the state DB can advance while the helper refreshes metadata.
        // Prefer the rollout mtime for live activity; otherwise history appears active
        // simply because it was inspected by the monitor.
        self.updatedAt = fileUpdate ?? indexedUpdate
        self.status = json["status"] as? [String: Any] ?? [:]
    }
}

private struct TurnSummary {
    let status: String?
    let hasQuestions: Bool
    let promptSummary: String?
}
