import XCTest
@testable import GraphCodex

final class JSONRPCDispatcherTests: XCTestCase {
    func testApprovalRequestReceivesProtocolErrorWithoutAnyApprovalDecision() throws {
        let incoming: [String: Any] = [
            "id": 74,
            "method": "item/commandExecution/requestApproval",
            "params": ["threadId": "thread-1", "itemId": "item-2"]
        ]

        let handled = try XCTUnwrap(CodexServerRequestRouter.response(for: incoming))

        XCTAssertEqual(handled.response["id"] as? Int, 74)
        XCTAssertNotNil(handled.response["error"])
        XCTAssertNil(handled.response["result"])
        XCTAssertNil(handled.response["decision"])
        XCTAssertTrue(handled.notice?.contains("Nenhuma ação foi aprovada") == true)
    }

    func testNotificationsDoNotGenerateJSONRPCResponses() {
        let notification: [String: Any] = ["method": "turn/started", "params": ["threadId": "thread-1"]]
        XCTAssertNil(CodexServerRequestRouter.response(for: notification))
    }
}
