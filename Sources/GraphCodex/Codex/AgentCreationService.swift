import Foundation

enum AgentCreationError: LocalizedError {
    case malformedThreadResponse
    case turnStartFailed(threadID: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .malformedThreadResponse:
            "O app-server do Codex não retornou o identificador da nova conversa."
        case .turnStartFailed(let threadID, let underlying):
            "A conversa \(threadID) foi criada, mas o turno não iniciou: \(underlying.localizedDescription)"
        }
    }
}

final class AgentCreationService: Sendable {
    private let transport: any CodexTransport

    init(transport: any CodexTransport) {
        self.transport = transport
    }

    func start(_ draft: AgentDraft, approvedPrompt: String) async throws -> String {
        let creation: (method: String, params: [String: Any])
        switch draft.contextSource {
        case .cloneFullHistory(let sourceThreadID):
            creation = ("thread/fork", ["threadId": sourceThreadID, "cwd": draft.workingDirectory, "excludeTurns": false])
        default:
            creation = ("thread/start", ["cwd": draft.workingDirectory])
        }

        let response = try await transport.request(method: creation.method, params: creation.params)
        guard let threadID = (response["thread"] as? [String: Any])?["id"] as? String else {
            throw AgentCreationError.malformedThreadResponse
        }

        do {
            _ = try await transport.request(method: "turn/start", params: [
                "threadId": threadID,
                "input": [["type": "text", "text": approvedPrompt]]
            ])
        } catch {
            throw AgentCreationError.turnStartFailed(threadID: threadID, underlying: error)
        }
        return threadID
    }
}
