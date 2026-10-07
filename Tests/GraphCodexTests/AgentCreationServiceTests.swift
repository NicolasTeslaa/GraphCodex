import XCTest
@testable import GraphCodex

final class AgentCreationServiceTests: XCTestCase {
    func testExplicitStartCreatesThreadThenSendsReviewedPrompt() async throws {
        let transport = RecordingCodexTransport()
        let service = AgentCreationService(transport: transport)
        let draft = AgentDraft(name: "QA", goal: "Verificar o fluxo", role: .qa,
                               priority: .high, tags: ["release"], projectID: "verval",
                               workingDirectory: "/work/verval", contextSource: .blank)

        let threadID = try await service.start(draft, approvedPrompt: "Prompt revisado pelo usuário")

        XCTAssertEqual(threadID, "thread-created")
        XCTAssertEqual(transport.calls.map(\.method), ["thread/start", "turn/start"])
        XCTAssertEqual(transport.calls[0].params["cwd"] as? String, "/work/verval")
        let input = try XCTUnwrap(transport.calls[1].params["input"] as? [[String: Any]])
        XCTAssertEqual(input.first?["text"] as? String, "Prompt revisado pelo usuário")
        XCTAssertNil(transport.calls[0].params["approvalPolicy"])
        XCTAssertNil(transport.calls[0].params["sandbox"])
    }

    func testFullHistoryCloneForksIntoChosenFolderBeforeStartingTurn() async throws {
        let transport = RecordingCodexTransport()
        let service = AgentCreationService(transport: transport)
        let draft = AgentDraft(name: "Frontend", goal: "Ajustar interface", role: .frontend,
                               priority: .normal, tags: [], projectID: "verval",
                               workingDirectory: "/work/other", contextSource: .cloneFullHistory(threadID: "source"))

        _ = try await service.start(draft, approvedPrompt: "Continue no novo diretório")

        XCTAssertEqual(transport.calls.map(\.method), ["thread/fork", "turn/start"])
        XCTAssertEqual(transport.calls[0].params["threadId"] as? String, "source")
        XCTAssertEqual(transport.calls[0].params["cwd"] as? String, "/work/other")
        XCTAssertEqual(transport.calls[0].params["excludeTurns"] as? Bool, false)
        XCTAssertEqual(transport.calls[1].params["threadId"] as? String, "thread-created")
    }
}

private final class RecordingCodexTransport: CodexTransport, @unchecked Sendable {
    struct Call {
        var method: String
        var params: [String: Any]
    }

    private let lock = NSLock()
    private var recordedCalls: [Call] = []
    var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return recordedCalls
    }

    func request(method: String, params: [String: Any]) async throws -> [String: Any] {
        lock.withLock { recordedCalls.append(Call(method: method, params: params)) }
        if method == "thread/start" || method == "thread/fork" {
            return ["thread": ["id": "thread-created"]]
        }
        return [:]
    }
}
